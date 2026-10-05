# Day 4 AWS lab (optional): inspection with an appliance-mode toggle

## Why this one is on AWS

Every other lab in this course runs in local namespaces. This one does not, because the
behaviour it teaches exists only in AWS: a Transit Gateway chooses which Availability
Zone's network interface carries each direction of a flow into an inspection VPC, and
the `appliance_mode_support` flag on the attachment changes that choice. The local
`labs/day04/inspection.sh` imitates the *effect* with policy routing. It cannot show
you the TGW making the choice. Do the local emulation first. Do this lab if you want to
see the real device behave that way.

It is optional. Budget about 60 minutes and about $0.60 per hour in ap-southeast-1 (six NAT gateways and three TGW attachments dominate; before data transfer) <!-- fact-checked 2026-10-05 -->
while it runs: three VPCs with two NAT gateways each (the shared `vpc` module creates
them), three TGW attachments, and four `t3.micro` instances. Destroy it when you finish.

## What it builds

```
 spoke-a 10.41.0.0/16          spoke-b 10.42.0.0/16
   ec2_a (AZ-a)                   ec2_b (AZ-b)
        \                           /
         +---- Transit Gateway ----+
                    |
        inspection 10.40.0.0/16
          fw-a (AZ-a)   fw-b (AZ-b)
```

- **Three VPCs** from `../../../aws_network_components/terraform/modules/vpc`,
  two AZs each. The module also gives each VPC NAT gateways, which the instances use to
  reach SSM and the package repository.
- **One TGW** with default association and propagation off. Route table `spokes` is
  associated with both spokes and has one static route, `0.0.0.0/0` to the inspection
  attachment. Route table `inspection` is associated with the inspection attachment and
  receives both spokes' routes by propagation.
- **VPC routes.** Spoke private route tables send `10.0.0.0/8` to the TGW. Inspection
  private route tables send `10.0.0.0/8` to the firewall in the same AZ.
- **Two firewalls**, plain Linux instances (Amazon Linux 2023, `t3.micro`,
  source/destination check off), with IP forwarding on and the stateful forward policy
  from Day 4 in `user_data.sh.tftpl`: established and related accepted, invalid dropped
  with a counter, new connections from `10.0.0.0/8` accepted. The firewall here is your
  Day 4 policy.
- **Two test instances**, `ec2_a` in spoke-a AZ-a and `ec2_b` in spoke-b AZ-b, running an
  echo server on port 8080, so every flow between them crosses AZs.

One simplification to know about. A production inspection VPC gives the TGW attachment
dedicated small subnets (one per AZ, each with its own route table) and puts the
firewalls in other subnets. Here the attachment reuses the inspection *private* subnets,
whose per-AZ route tables send `10.0.0.0/8` to the firewall in the same AZ. The
firewalls sit in the inspection *public* subnets, which share one route table whose
`10.0.0.0/8` route points back at the TGW. A `10.0.0.0/8` route to the firewall's own ENI in the firewall's own subnet would make
it send its forwarded traffic back to itself, so the split keeps the two
directions of the route logic apart. The firewalls get a public IPv4 address only to
reach SSM and the package repository through the internet gateway. Their security group
admits nothing from the internet.

The VPC routes are `aws_route` resources added to route tables that the module creates
with an inline default route. That pattern works for a lab (the TGW module in the sibling
course does the same). Do not copy it into a production module.

## Run it

```bash
cd aws_lab/day04
cp terraform.tfvars.example terraform.tfvars      # profile "sandbox", region ap-southeast-1
terraform init
terraform apply -var appliance_mode=false
```

Wait about 3 minutes after the apply for the firewalls' `user_data` to finish. Then
open a shell on `ec2_a` with Session Manager (the instance IDs are in the outputs):

```bash
aws ssm start-session --profile sandbox --region ap-southeast-1 \
  --target "$(terraform output -raw ec2_a_instance_id)"
```

### 1. appliance mode off: flows hang

From `ec2_a`, run a connect test to `ec2_b` repeatedly (use the private IP from
`terraform output ec2_b_private_ip`):

```bash
for i in $(seq 1 10); do nc -zw 3 <ec2_b_ip> 8080 && echo ok || echo FAIL; done
```

(Each `nc` uses a new source port. The test instances run an echo server, not a web
server, so `nc -z` is the cleaner probe than `curl`. `curl -m 5 --http0.9 <ec2_b_ip>:8080`
also connects.) Expect connections to hang until the timeout. A flow from AZ-a to AZ-b
reaches the firewall in AZ-a on the way out and the firewall in AZ-b on the way back, so
the reply meets a firewall that has no flow. If a few connections do succeed, note which
and why in `journal.md`: the spoke instance's own AZ decides, so traffic that stays in one
AZ passes.

On both firewalls (Session Manager again, `terraform output firewall_instance_ids`):

```bash
sudo nft list ruleset        # the invalid counter rises on the AZ-b firewall
sudo conntrack -L            # AZ-a: a flow stuck in SYN_SENT. AZ-b: no flow for it
```

The AZ-b firewall counts the SYN-ACKs as invalid. This is the Day 4 lab, at
a TGW. The TGW picks the inspection network interface in the AZ of the traffic's *source*
<!-- fact-checked 2026-10-05 -->, once per direction.

### 2. appliance mode on: 100% success

```bash
terraform apply -var appliance_mode=true
```

Run the same loop. Expect ten `ok`. Appliance mode pins both directions of a flow to
one AZ's interface on the inspection attachment. Read `nft list ruleset` and
`conntrack -L` again: one firewall now holds the whole flow, and the invalid counters
stay flat.

Turn it back off and on once more if you want to see the behaviour change with the one
attribute and nothing else. Note that the attachment is modified in place. Flows that
started before the change may keep their old path until they close, so test with new
connections.

## Teardown

```bash
# run from aws_lab/day04; the sweep path is relative to it
terraform destroy -var appliance_mode=false
../../../aws_network_components/scripts/sweep.sh sandbox ap-southeast-1
```

`sweep.sh` lists anything that can still bill you (NAT gateways, Elastic IPs and so on).
The apply takes several minutes in each direction because of the NAT gateways and
the TGW attachments, so leave time for the destroy. Do not leave this running overnight.

## Files

- `main.tf` the whole root: VPCs, TGW, routes, firewalls, test instances
- `variables.tf` `region`, `aws_profile`, `appliance_mode`
- `outputs.tf` instance IDs and private IPs
- `user_data.sh.tftpl` the firewall's bootstrap: nftables, forwarding, the policy
- `terraform.tfvars.example` a copy of the defaults, with no account IDs or keys
