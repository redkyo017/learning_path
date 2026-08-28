# AWS Enterprise Integration Patterns — Glossary

Reference for all pattern terms used across Days 1–5. Each entry gives a plain-English definition and one enterprise example.

---

## Ingress and API patterns

**API Gateway (pattern)** — An architectural pattern in which a single entry-point service sits in front of multiple backend services, handling routing, auth, rate limiting, and protocol translation on behalf of callers. This is a design pattern independent of any specific AWS service. Example: A retail platform routes `/orders`, `/inventory`, and `/payments` paths through one gateway instead of exposing three separate backend URLs to mobile clients.

**Backend-for-Frontend (BFF)** — A specialized API Gateway variant that creates one tailored API per client type (web, mobile, partner) rather than a single generic API for all consumers. Each BFF shapes responses to exactly what its client needs, avoiding over-fetching. Example: A banking app runs a slim mobile BFF that returns only account summary fields, while the desktop BFF returns full transaction history.

**API Composition / Aggregation** — A pattern where a gateway or service stitches together calls to multiple downstream services and returns a single merged response to the caller, hiding the fan-out from the client. Example: A travel portal's search API calls flights, hotels, and car-rental services in parallel and merges the results into one JSON response.

**Reverse Proxy** — A server that sits in front of one or more backends, forwarding client requests and returning backend responses, so clients never talk directly to origin services. It can add TLS termination, caching, or load balancing. Example: An Nginx instance in front of three app servers distributes HTTP traffic and terminates HTTPS so the app servers handle plain HTTP internally.

**L4 ingress / L7 ingress** — Two levels at which a load balancer or gateway can inspect and route traffic. L4 (transport layer) routes by IP/TCP only; L7 (application layer) can inspect HTTP headers, paths, and host names. Example: An L4 Network Load Balancer routes raw TCP to a database cluster, while an L7 Application Load Balancer routes `/api/*` to one target group and `/static/*` to another.

**Weighted routing** — A traffic-distribution technique that splits a percentage of requests to one target and the remainder to another, enabling gradual traffic shifting for canary deployments or A/B tests. Example: Route 10 % of production traffic to a new service version while 90 % still hits the stable version, then increase the weight incrementally.

**Blue-green deployment** — A release pattern that runs two identical environments (blue = current, green = new version) and shifts 100% of traffic from blue to green in one cut-over, with instant rollback by shifting back. Contrast with canary (gradual shift). Example: A banking API team deploys v2 to the green ALB target group and uses weighted routing to shift 100% traffic once smoke tests pass, keeping blue available for 30 minutes before terminating it.

**Header-based routing** — Routing decisions made by inspecting HTTP request headers (e.g., `X-Client-Version`, `Accept`, `Authorization` tenant ID) rather than just URL paths. Example: An API Gateway forwards requests with `X-Tenant: enterprise` to a premium backend pool and all others to the standard pool.

**mTLS** — Mutual TLS is a variant of TLS where both the client and the server present certificates to each other, so each side cryptographically proves its identity. This is stronger than server-only TLS and is used for zero-trust service-to-service authentication. Example: An API Gateway custom domain enforces mTLS so that only microservices holding a valid client certificate issued by the company's internal CA can call the endpoint.

**WAF integration (as a pattern)** — Placing a Web Application Firewall in the request path so that malicious traffic (SQL injection, XSS, bad bots, IP blocks) is filtered before it reaches application code. Example: An ALB listener rule chains to AWS WAF rules that block known attack patterns before requests reach an ECS-based API.

**CDN + origin offload** — Using a Content Delivery Network to cache responses at edge locations so the origin server receives only cache-miss requests, reducing latency for end-users and load on the origin. Example: A media company serves video thumbnails through CloudFront; the S3 origin handles only the first request per object per edge location, then the CDN serves all subsequent requests.

**Anti-Corruption Layer (ACL)** — A translation boundary placed between a new service and a legacy system so that each side uses its own model; the ACL translates between them without letting the legacy model "corrupt" the clean design of the new service. Example: A modern order service calls a 20-year-old mainframe ERP through an ACL that converts REST JSON to SOAP XML and maps field names, so neither side knows about the other's structure.

---

## Egress and VPC connectivity patterns

**NAT Gateway (when correct vs wrong)** — A managed service that lets private subnet resources initiate outbound internet connections. Correct use: a private EC2 or Lambda calling a public SaaS API. Wrong use: routing traffic to other AWS services (S3, DynamoDB) through NAT, which adds cost and latency — use VPC endpoints instead. Example: A batch job in a private subnet downloads updates from a public package registry via NAT Gateway; calls to S3 bypass NAT using a Gateway Endpoint.

**VPC Gateway Endpoint** — A free, highly-available VPC construct that routes traffic to S3 or DynamoDB over the AWS private network without requiring NAT or an internet gateway. Traffic never leaves the AWS backbone. Example: An analytics pipeline in a private subnet writes Parquet files to S3 via a Gateway Endpoint, incurring no NAT data-processing charges.

**VPC Interface Endpoint (PrivateLink)** — An elastic network interface placed inside your VPC that gives you a private IP address to reach AWS services or partner services over PrivateLink, keeping traffic off the internet. Example: A regulated financial workload calls AWS Secrets Manager through an Interface Endpoint so credentials are never fetched over the public internet.

**PrivateLink as service exposure pattern** — A pattern where a service provider exposes an NLB-backed service through AWS PrivateLink, and consumers connect to it via Interface Endpoints in their own VPCs, with no VPC peering or route-table complexity required. Example: A SaaS vendor exposes its data ingestion API as a PrivateLink service; enterprise customers consume it from their private subnets without opening inbound internet access.

**VPC Peering** — A point-to-point private network connection between two VPCs that lets instances in each VPC communicate using private IPs as if they were on the same network. Does not support transitive routing. Example: A shared-services VPC (monitoring, logging) is peered with each product VPC so services can ship metrics without traversing the internet.

**Transit Gateway** — A regional hub that connects many VPCs, on-premises networks, and AWS accounts through a single managed router, replacing the mesh of VPC peering connections needed at scale. Supports transitive routing. Example: A company with 30 VPCs across 5 accounts attaches all of them to a Transit Gateway instead of managing 435 individual peering connections.

**Split-horizon DNS** — A DNS configuration where the same domain name resolves to different IP addresses depending on whether the query comes from inside or outside a network. Internal clients get private IPs; external clients get public IPs. Example: `api.example.com` resolves to a private ALB IP for traffic originating inside the corporate VPC and to a public ALB IP for internet clients.

---

## Service-to-service resilience patterns

**Service discovery** — A mechanism by which services locate each other dynamically at runtime rather than through hard-coded IPs or hostnames, enabling instances to come and go without configuration changes. Example: ECS tasks register themselves in AWS Cloud Map; a calling service queries Cloud Map to find the current healthy IPs for a dependency.

**Load balancing strategies (LOR)** — Algorithms that determine which target receives the next request. Round-robin cycles through targets equally; least outstanding requests (LOR) sends to the target with fewest in-flight requests — better for variable response times. Example: An ALB using LOR routes fewer requests to a payment service instance that is slower than its peers, naturally reducing its load without health-check intervention.

**Circuit breaker** — A stability pattern that monitors calls to a downstream service and, after a threshold of failures, "opens" the circuit so further calls fail fast (without waiting for a timeout) until the downstream recovers. Example: An order service stops calling a slow inventory service after 50 % of requests fail in 30 seconds; it returns a cached stock estimate instead until the circuit closes again.

**Timeout + retry budget** — The practice of setting an explicit maximum wait time on every outbound call (timeout) and limiting the total number of retries across the call chain so a slow dependency cannot block threads or cause retry storms. Example: A payment gateway sets a 2-second timeout on card-network calls and allows at most 2 retries with exponential back-off, after which it returns an error rather than retrying indefinitely.

**Bulkhead** — A pattern that isolates failures by partitioning resource pools (thread pools, connection pools, queues) so that exhaustion caused by one dependency cannot starve calls to unrelated dependencies. Example: An API server uses separate thread pools for calls to the inventory service and the pricing service; a slow inventory response does not consume threads that pricing calls need.

---

## Async messaging patterns

**Point-to-point queue** — A messaging pattern where exactly one consumer processes each message from a queue. Producers and consumers are decoupled in time; the queue buffers messages until a consumer is ready. Example: An e-commerce site enqueues order-confirmation jobs in SQS; a fleet of worker Lambdas each pick up and process one message at a time.

**Pub-sub** — A messaging pattern where a producer publishes a message to a topic, and every subscriber to that topic receives a copy. One event can trigger many independent consumers. Example: A payment service publishes a `PaymentCompleted` event to an SNS topic; a receipts service, a fraud-detection service, and a loyalty-points service each subscribe and react independently.

**Outbox pattern** — A technique for achieving atomicity between a database write and a message publish: the service writes the event to an "outbox" table in the same database transaction as the domain change, then a separate relay process reads the outbox and publishes to the message broker. Example: An order service inserts a new order row and an outbox event row in one transaction; a Debezium-based relay reads the outbox via CDC and publishes to Kafka, ensuring no event is lost if the app crashes after the DB write.

**Fan-out to queues** — A pattern where an SNS topic (or equivalent) distributes a single message to multiple SQS queues so that each consumer group gets its own copy and can process at its own pace without competing with other consumers. Example: A `UserRegistered` SNS topic fans out to a welcome-email SQS queue, an onboarding-workflow SQS queue, and a CRM-sync SQS queue; each processes independently.

**Outbound webhook / event push** — A pattern where your system proactively notifies external consumers when an event occurs, by making an HTTP POST to a consumer-provided URL. Delivery is at-least-once; consumers must be idempotent. Example: A payment platform calls a merchant's configured webhook URL whenever a transaction settles, including an HMAC signature so the merchant can verify authenticity.

**Dead-letter queue (DLQ)** — A queue that receives messages that could not be successfully processed after a configured number of attempts, providing a holding area for poison messages that can be inspected and redriven without blocking the main queue. Example: An SQS queue for invoice processing sends messages that fail five consecutive times to a DLQ; an ops team inspects them, fixes the bug, then redrives them back to the main queue.

---

## External / webhook integration patterns

**Inbound webhook receiver** — A publicly accessible HTTP endpoint that accepts push notifications from an external system (payment processor, CI/CD platform, SaaS tool) and converts the inbound call into an internal event or action. Example: A GitHub webhook POSTs `push` events to an API Gateway endpoint; the Lambda handler validates the signature and enqueues a build job.

**Idempotency key** — A unique identifier included in a request so that if the same request is delivered more than once (network retry, at-least-once delivery), the server can detect the duplicate and return the same result without performing the operation twice. Example: A payment client generates a UUID for each charge request and sends it as `Idempotency-Key: <uuid>`; the payment service ignores any retry that reuses an already-processed key.

**Webhook signature validation** — The practice of verifying that an inbound webhook payload was genuinely sent by the expected external party, typically by computing an HMAC of the payload using a shared secret and comparing it to a signature header sent by the caller. Example: A Stripe webhook handler recomputes `HMAC-SHA256(payload, STRIPE_SECRET)` and rejects any request whose `Stripe-Signature` header does not match.

**Polling vs push** — Two strategies for receiving data from an external system. Polling: your service repeatedly queries the external system on a schedule. Push (webhook/event): the external system notifies your service when data is ready. Polling wastes resources when nothing changes; push is more efficient but requires a reachable endpoint. Example: An old integration polls an FTP server every 5 minutes for new files; a modern replacement subscribes to S3 event notifications that trigger Lambda instantly when a file arrives.

---

## Multi-account and cross-boundary patterns

**Cross-account access patterns** — Techniques for one AWS account to securely access resources in another without sharing long-lived credentials. Common approaches: IAM role assumption via `sts:AssumeRole`, resource-based policies (S3 bucket policy granting another account), and PrivateLink service exposure. Example: A central security account assumes a read-only IAM role in each workload account to collect CloudTrail logs without storing IAM keys in the security account.
