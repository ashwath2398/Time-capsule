# ⏳ Serverless Time Capsule

A fully serverless application that allows users to send messages to the "future." Messages are stored securely and automatically emailed back to the user after a specific duration using DynamoDB's Time-To-Live (TTL) feature.

## 🏗️ Architecture

This project uses an **Event-Driven Architecture** built entirely on AWS Free Tier services.

**The Data Flow:**
1.  **Input:** User submits a message via a simple HTML frontend.
2.  **Ingestion:** API Gateway receives the request and triggers the `Save` Lambda.
3.  **Storage:** Lambda saves the message to **DynamoDB** with a specific `expiration_time` (TTL).
4.  **The Wait:** DynamoDB holds the item. When the TTL expires, its background process deletes the item.
5.  **The Trigger:** The deletion creates a `REMOVE` event in the **DynamoDB Stream**.
6.  **Delivery:** The stream triggers the `Email` Lambda, which uses **Amazon SES** to send the message back to the user.

```mermaid
graph TD
    User[User (HTML UI)] -->|POST /save_message| APIG[API Gateway]
    APIG -->|Trigger| Lambda1[Lambda: Save Message]
    Lambda1 -->|Put Item (with TTL)| DDB[(DynamoDB Table)]
    DDB -->|TTL Expiry (Delete)| Stream{DynamoDB Stream}
    Stream -->|Trigger (REMOVE Event)| Lambda2[Lambda: Send Email]
    Lambda2 -->|Send Mail| SES[Amazon SES]
    SES -->|Email| User