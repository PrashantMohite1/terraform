

# AWS Systems Manager Session Manager

## Overview

Session Manager provides secure, browser-based, interactive shell access to your instances without needing bastion hosts or open inbound ports.

## How It Works

SSM Session Manager does NOT require SSH connectivity from your laptop to the private EC2 instance. Instead, the EC2 instance itself initiates an outbound connection to AWS Systems Manager (SSM).

Essentially, the SSM agent runs on the EC2 instance and connects to the SSM Manager service over TCP 443 via the SSM Manager endpoint. Once connected, you can access the instance through that persistent connection. 


## Connection Flow

### Traditional Model (E.g., Google)

When your EC2 initiates a connection to an external service like Google:

```
EC2                         Google
 |                            |
 | ---- "Hello" ------------> |
 |                            |
 | <---- "Hello back" ------- |
```

The EC2 initiates the outbound connection, and once established, both parties can exchange data through that connection.

### SSM Model

The same principle applies to AWS Systems Manager:

```
Private EC2                         AWS SSM
    |                                  |
    | -------- outbound ------------> |
    |                                  |
    | <------- response/data ---------|
    |                                  |
```

The private EC2 initiates the outbound connection to SSM. Once established, you can securely send commands and receive responses through that connection.

