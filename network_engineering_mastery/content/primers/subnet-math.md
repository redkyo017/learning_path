# Subnet math primer

You can do every calculation in this course with one number, the block size, and a table
of powers of two. This primer gives the method, the /8-/32 table, summarization and
containment, the IPv6 nibble rule, and 30 drills. Cover the answers and write yours down
before you open the answer.

## The block-size method

1. Find the octet where the prefix boundary falls: octet = ceil(prefix / 8).
2. **block size = 256 - mask octet value.** Example /26: mask octet is 192, block is 64.
3. The network address is the largest multiple of the block size that is not above the
   address's value in that octet. Everything after that octet is 0.
4. The broadcast address is the network address + block size - 1 in that octet,
   with all later octets 255.
5. Usable hosts are the addresses between them: 2^(host bits) - 2.

Worked example, 172.16.45.9/20. The boundary is in the third octet. Mask octet is 240,
block is 16. Multiples of 16: 0, 16, 32, 48. The largest not above 45 is 32. Network
172.16.32.0, broadcast 172.16.47.255, usable 172.16.32.1 - 172.16.47.254.

Mask octet values you must know: 128, 192, 224, 240, 248, 252, 254, 255 (one to eight bits
on). The blocks are 128, 64, 32, 16, 8, 4, 2, 1.

## The /8 to /32 table

The block column gives the step between subnets in the octet that holds the last mask bit
(octet 1 is the first number of the address). Whole-octet prefixes step by 1.

| Prefix | Mask | Usable hosts | Block |
|---|---|---|---|
| /8 | 255.0.0.0 | 16777214 | 1 in octet 1 |
| /9 | 255.128.0.0 | 8388606 | 128 in octet 2 |
| /10 | 255.192.0.0 | 4194302 | 64 in octet 2 |
| /11 | 255.224.0.0 | 2097150 | 32 in octet 2 |
| /12 | 255.240.0.0 | 1048574 | 16 in octet 2 |
| /13 | 255.248.0.0 | 524286 | 8 in octet 2 |
| /14 | 255.252.0.0 | 262142 | 4 in octet 2 |
| /15 | 255.254.0.0 | 131070 | 2 in octet 2 |
| /16 | 255.255.0.0 | 65534 | 1 in octet 2 |
| /17 | 255.255.128.0 | 32766 | 128 in octet 3 |
| /18 | 255.255.192.0 | 16382 | 64 in octet 3 |
| /19 | 255.255.224.0 | 8190 | 32 in octet 3 |
| /20 | 255.255.240.0 | 4094 | 16 in octet 3 |
| /21 | 255.255.248.0 | 2046 | 8 in octet 3 |
| /22 | 255.255.252.0 | 1022 | 4 in octet 3 |
| /23 | 255.255.254.0 | 510 | 2 in octet 3 |
| /24 | 255.255.255.0 | 254 | 1 in octet 3 |
| /25 | 255.255.255.128 | 126 | 128 in octet 4 |
| /26 | 255.255.255.192 | 62 | 64 in octet 4 |
| /27 | 255.255.255.224 | 30 | 32 in octet 4 |
| /28 | 255.255.255.240 | 14 | 16 in octet 4 |
| /29 | 255.255.255.248 | 6 | 8 in octet 4 |
| /30 | 255.255.255.252 | 2 | 4 in octet 4 |
| /31 | 255.255.255.254 | 2 (point-to-point, RFC 3021) | 2 in octet 4 |
| /32 | 255.255.255.255 | 1 (a single host) | 1 in octet 4 |

## Summarization and containment

**Containment test.** An address is in a prefix if it lies between the network and
broadcast address. With the block size: find the network address for the *candidate*
prefix, and check the address falls in `network .. network + block - 1`.

**Summarization** merges contiguous prefixes into one shorter prefix. It works only when
both conditions hold:

1. The number of prefixes is a power of two (2, 4, 8, ...).
2. The first one starts on a multiple of the combined block size.

Each doubling of the count removes one bit from the prefix. 2 x /24 -> /23, 4 x /24 ->
/22, 8 x /24 -> /21. If the first prefix is not aligned, the summary is wider than what
you meant, and it advertises addresses you do not own. That is how a sloppy summary
becomes an outage or a leak. Check the summary by listing its first and last address
and comparing them with your range.

Routers pick among overlapping prefixes by longest-prefix match: the more specific route
wins, regardless of where it came from. A summary and a more specific route can coexist,
and the specific one takes its own traffic.

## IPv6 nibble boundaries

An IPv6 address is 32 hex digits, so each digit (nibble) is 4 bits. A prefix that is a
multiple of 4 ends exactly between two digits, and you can read the network off the
address by eye. A prefix that is not a multiple of 4 cuts a digit in the middle.

- /48 ends after the third group, /64 after the fourth. Every group is 16 bits, so
  /16, /32, /48, /64, /80, /96, /112 end on a colon.
- /52, /56 and /60 end after one, two and three nibbles of a group. A /56 fixes the first
  two digits of the fourth group and leaves two to vary: 2001:db8:abcd:1200::/56
  covers fourth group 1200 - 12ff.
- Subnets in a prefix: 2^(64 - prefix) /64s. A /48 holds 65,536 and a /56 holds 256.
- Compression: drop leading zeros in each group, and replace the longest run of all-zero
  groups with `::`, once only. Link-local is `fe80::/10`, unique-local is `fd00::/8`
  (the `fc00::/7` block), documentation is `2001:db8::/32`.

For the course labs, /64 is the subnet size for a host network, as SLAAC requires it.

## Drills

### Drill 1

How many usable hosts are in a /26?

<details>
<summary>Hint and answer</summary>

**Hint:** Host bits = 32 - 26 = 6. 2^6 = 64 addresses, minus network and broadcast.

**Answer:** **62** usable hosts.

</details>

### Drill 2

Write /27 as a dotted mask.

<details>
<summary>Hint and answer</summary>

**Hint:** 27 = 24 + 3 bits in the last octet. 3 bits on = 128 + 64 + 32 = 224.

**Answer:** **255.255.255.224**

</details>

### Drill 3

Network and broadcast of 10.1.1.77/26.

<details>
<summary>Hint and answer</summary>

**Hint:** Block = 256 - 192 = 64. Multiples of 64 in the last octet: 0, 64, 128, 192.

**Answer:** Network **10.1.1.64**, broadcast **10.1.1.127**, usable .65 - .126.

</details>

### Drill 4

Network, broadcast and usable range of 192.168.5.200/28.

<details>
<summary>Hint and answer</summary>

**Hint:** Block = 256 - 240 = 16. Largest multiple of 16 not above 200 is 192.

**Answer:** Network **192.168.5.192**, broadcast **192.168.5.207**, usable .193 - .206.

</details>

### Drill 5

Network and broadcast of 172.16.45.9/20.

<details>
<summary>Hint and answer</summary>

**Hint:** The boundary is in the third octet. Block = 256 - 240 = 16. Largest multiple of 16 not above 45 is 32.

**Answer:** Network **172.16.32.0**, broadcast **172.16.47.255**.

</details>

### Drill 6

Smallest prefix that holds 500 hosts.

<details>
<summary>Hint and answer</summary>

**Hint:** You need 500 + 2 = 502 addresses. 2^8 = 256 is too small, 2^9 = 512 fits, so 9 host bits.

**Answer:** **/23** (510 usable).

</details>

### Drill 7

Smallest prefix that holds 60 hosts.

<details>
<summary>Hint and answer</summary>

**Hint:** 60 + 2 = 62. 2^6 = 64 fits, so 6 host bits.

**Answer:** **/26** (62 usable).

</details>

### Drill 8

Split 10.0.0.0/24 into 8 equal subnets. Give the prefix, block size and the last subnet.

<details>
<summary>Hint and answer</summary>

**Hint:** 8 = 2^3, so borrow 3 bits: 24 + 3 = 27. Block = 256 / 8 = 32.

**Answer:** **/27**, block 32: .0 .32 .64 .96 .128 .160 .192 .224. The last is **10.0.0.224/27**.

</details>

### Drill 9

Is 10.1.2.130 inside 10.1.2.128/26?

<details>
<summary>Hint and answer</summary>

**Hint:** Block 64 starting at 128 covers 128 - 191.

**Answer:** **Yes** (130 is within 128 - 191).

</details>

### Drill 10

Is 10.1.2.200 inside 10.1.2.128/26?

<details>
<summary>Hint and answer</summary>

**Hint:** Same range, 128 - 191. Where does 200 fall?

**Answer:** **No**. 200 is above the broadcast address 191.

</details>

### Drill 11

Summarize 192.168.0.0/24 through 192.168.3.0/24 into one prefix.

<details>
<summary>Hint and answer</summary>

**Hint:** Four consecutive /24s are 2^2 blocks, and 0 is a multiple of 4. Third octet 0 - 3 means two bits vary: 24 - 2.

**Answer:** **192.168.0.0/22**.

</details>

### Drill 12

Summarize 10.0.4.0/24 and 10.0.5.0/24.

<details>
<summary>Hint and answer</summary>

**Hint:** Two blocks, so one bit varies: /23. Does 4 line up on a multiple of 2?

**Answer:** **10.0.4.0/23**.

</details>

### Drill 13

Can 10.0.1.0/24 and 10.0.2.0/24 be summarized exactly into one prefix? If not, what is the smallest single prefix that covers both, and what does it over-cover?

<details>
<summary>Hint and answer</summary>

**Hint:** A /23 must start on an even third octet. 1 is odd, so 1-2 is not a /23 block. Try /22 (blocks of 4: 0 - 3).

**Answer:** **Not exactly.** The smallest covering prefix is **10.0.0.0/22**, which also covers 10.0.0.0/24 and 10.0.3.0/24 that you did not mean to include.

</details>

### Drill 14

Smallest single prefix that exactly summarizes 172.16.8.0/24 through 172.16.15.0/24.

<details>
<summary>Hint and answer</summary>

**Hint:** Eight /24s = 2^3, so 3 bits vary: /21. Does 8 line up on a multiple of 8?

**Answer:** **172.16.8.0/21**.

</details>

### Drill 15

Usable hosts in a /30, a /31 and a /32?

<details>
<summary>Hint and answer</summary>

**Hint:** /30 has 4 addresses minus 2. A /31 is the point-to-point exception (RFC 3021). A /32 is one address.

**Answer:** /30: **2**. /31: **2** (no network or broadcast). /32: **1**.

</details>

### Drill 16

Subnet 192.168.10.0/24 for three LANs of 100, 50 and 20 hosts. Allocate largest first.

<details>
<summary>Hint and answer</summary>

**Hint:** 100 + 2 needs 2^7 = 128 (/25). 50 + 2 needs 64 (/26). 20 + 2 needs 32 (/27). Place each at the next free block boundary.

**Answer:** **192.168.10.0/25** (0 - 127), **192.168.10.128/26** (128 - 191), **192.168.10.192/27** (192 - 223). 224 - 255 stays free.

</details>

### Drill 17

The routing table holds 10.0.0.0/8, 10.1.0.0/16, 10.1.2.0/24 and 0.0.0.0/0. Which route carries a packet to 10.1.2.3?

<details>
<summary>Hint and answer</summary>

**Hint:** All four match. Longest-prefix match picks the one with the most prefix bits.

**Answer:** **10.1.2.0/24**.

</details>

### Drill 18

The table holds 10.1.2.0/25 and 10.1.0.0/16. Which route carries a packet to 10.1.2.200?

<details>
<summary>Hint and answer</summary>

**Hint:** 10.1.2.0/25 covers .0 - .127 only. Does .200 fall inside it?

**Answer:** **10.1.0.0/16**. The /25 does not match (200 > 127), so the shorter prefix is the best match.

</details>

### Drill 19

How many addresses can you assign in a /24 subnet in an AWS VPC, and in a /28? <!-- fact-checked 2026-10-05 -->

<details>
<summary>Hint and answer</summary>

**Hint:** AWS reserves five addresses in every subnet: the network address, the router, the DNS, one for future use, and the broadcast address. Subtract five from the total.

**Answer:** /24: 256 - 5 = **251**. /28: 16 - 5 = **11**.

</details>

### Drill 20

How many /24s fit in a /16, and how many /27s in a /24?

<details>
<summary>Hint and answer</summary>

**Hint:** Count the borrowed bits: 24 - 16 = 8, and 27 - 24 = 3.

**Answer:** 2^8 = **256** /24s, and 2^3 = **8** /27s.

</details>

### Drill 21

Is 100.100.1.1 inside the shared address space 100.64.0.0/10? Give the range of that block.

<details>
<summary>Hint and answer</summary>

**Hint:** A /10 has a block of 64 in the second octet, starting at 64.

**Answer:** **Yes.** The block is **100.64.0.0 - 100.127.255.255**.

</details>

### Drill 22

Network and broadcast of 203.0.113.99/29.

<details>
<summary>Hint and answer</summary>

**Hint:** Block = 256 - 248 = 8. Largest multiple of 8 not above 99 is 96.

**Answer:** Network **203.0.113.96**, broadcast **203.0.113.103**.

</details>

### Drill 23

What prefix length is the mask 255.255.240.0?

<details>
<summary>Hint and answer</summary>

**Hint:** Count the bits: 8 + 8 + 4 (240 = 1111 0000) + 0.

**Answer:** **/20**.

</details>

### Drill 24

What prefix length is the mask 255.255.255.248?

<details>
<summary>Hint and answer</summary>

**Hint:** 248 = 1111 1000, so five bits in the last octet.

**Answer:** **/29** (24 + 5).

</details>

### Drill 25

How many /64 subnets are in an IPv6 /48?

<details>
<summary>Hint and answer</summary>

**Hint:** Borrowed bits = 64 - 48 = 16.

**Answer:** 2^16 = **65,536**.

</details>

### Drill 26

How many /64 subnets are in an IPv6 /56?

<details>
<summary>Hint and answer</summary>

**Hint:** Borrowed bits = 64 - 56 = 8.

**Answer:** 2^8 = **256**.

</details>

### Drill 27

Which /48 and which /64 contain 2001:db8:abcd:12:3::1?

<details>
<summary>Hint and answer</summary>

**Hint:** A /48 keeps the first three groups (48 bits). A /64 keeps the first four groups.

**Answer:** /48: **2001:db8:abcd::/48**. /64: **2001:db8:abcd:12::/64**.

</details>

### Drill 28

Write 2001:db8::1 in full, then compress 2001:0db8:0000:0000:0001:0000:0000:0001.

<details>
<summary>Hint and answer</summary>

**Hint:** Expanding: each group is four hex digits, and :: stands for the missing zero groups. Compressing: drop leading zeros, then replace the longest run of zero groups with :: (the first run if tied, and only once).

**Answer:** Full: **2001:0db8:0000:0000:0000:0000:0000:0001**. Compressed: **2001:db8::1:0:0:1** (two runs of equal length, so the first one becomes ::).

</details>

### Drill 29

Which /52 contains 2001:db8:abcd:1234::1? Give the range of the fourth group.

<details>
<summary>Hint and answer</summary>

**Hint:** A /52 is 13 nibbles, so the fourth group is split: its first nibble is fixed, the other three vary.

**Answer:** **2001:db8:abcd:1000::/52**, covering fourth group 1000 - 1fff.

</details>

### Drill 30

Give the first and last address of 2001:db8:1::/48.

<details>
<summary>Hint and answer</summary>

**Hint:** The /48 fixes the first three groups. The remaining 80 bits are all zeros for the first address, all ones for the last.

**Answer:** First **2001:db8:1::**, last **2001:db8:1:ffff:ffff:ffff:ffff:ffff**.

</details>

