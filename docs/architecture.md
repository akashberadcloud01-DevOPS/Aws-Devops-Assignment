# AWS DevOps Assignment — Architecture Diagram

## Target Architecture

```mermaid
flowchart TB
    Users([Internet Users])

    subgraph AWS["AWS Cloud"]
        IGW[Internet Gateway]

        subgraph VPC["AWS VPC"]
            subgraph Public["Public Subnets - Multi-AZ"]
                ALB["Application Load Balancer<br/>HTTPS :443 - ACM Certificate"]
                NAT1["NAT Gateway - AZ A"]
                NAT2["NAT Gateway - AZ B"]
            end

            subgraph AppA["Private App Subnet - AZ A"]
                EC2A["EC2 Instance A<br/>Nginx"]
            end

            subgraph AppB["Private App Subnet - AZ B"]
                EC2B["EC2 Instance B<br/>Nginx"]
            end

            subgraph DB["Private Database Subnets"]
                RDS["Amazon RDS MySQL<br/>Primary"]
                Standby["RDS Standby<br/>Multi-AZ"]
            end

            Secrets["AWS Secrets Manager"]
            IAM["IAM Instance Role"]
        end

        S3App["S3 - Application Files"]
        S3Logs["S3 - ALB Access Logs"]
    end

    Users --> ALB
    IGW --- ALB
    ALB --> EC2A
    ALB --> EC2B
    EC2A --> RDS
    EC2B --> RDS
    RDS -. "Multi-AZ replication" .-> Standby
    Secrets -. "Database credentials" .-> EC2A
    Secrets -. "Database credentials" .-> EC2B
    IAM -. "Least-privilege access" .-> S3App
    S3App -. "Application HTML" .-> EC2A
    S3App -. "Application HTML" .-> EC2B
    ALB -. "Access logs" .-> S3Logs
    EC2A --> NAT1
    EC2B --> NAT2
    NAT1 --> IGW
    NAT2 --> IGW

    classDef network fill:#eaf3ff,stroke:#3973ac,color:#17365d
    classDef compute fill:#e7f5e9,stroke:#36834a,color:#174c25
    classDef database fill:#fff0db,stroke:#c47a19,color:#70420b
    classDef storage fill:#f0eaff,stroke:#8055b7,color:#3c2363

    class ALB,IGW,NAT1,NAT2 network
    class EC2A,EC2B compute
    class RDS,Standby database
    class S3App,S3Logs,Secrets storage
```

## CI/CD Workflow

```mermaid
flowchart LR
    A[Developer Pushes Code] --> B[GitHub Repository]
    B --> C[GitHub Actions]
    C --> D[Terraform Format]
    D --> E[Terraform Init]
    E --> F[Terraform Validate]
    F --> G[Terraform Plan]
    G --> H[Manual Approval]
    H --> I[Terraform Apply]
    I --> J[Deployment Health Checks]
```

## Notes

- This is the target architecture for the assignment.
- HTTPS requires a valid ACM certificate and an HTTPS listener on the ALB.
- The database is intended to remain in private subnets.
- The CI/CD diagram describes the intended pipeline; the current GitHub Actions workflow only performs Terraform formatting, initialization, and validation.
- Confirm all resources are deployed and configured before presenting the target architecture as the completed implementation.
