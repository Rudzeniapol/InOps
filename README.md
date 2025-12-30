**InOps – SaaS Incident Management Platform**

A high-load microservices system designed for DevOps teams to aggregate, deduplicate, and resolve infrastructure incidents in real-time (similar to PagerDuty). The platform processes alerts from monitoring tools, filters noise, and automates on-call notifications.

**Key Features & Tech Stack:**
*   **Microservices Backend:** Built with **Java Spring Boot**. Implements a hybrid database architecture using **PostgreSQL** for relational logic (schedules, user roles) and **MongoDB** for unstructured alert logs.
*   **High Performance:** Utilizes **Redis** for efficient alert deduplication (handling "alert storms") and caching hot data.
*   **Frontend:** Developed with **React, Vite, TypeScript**, and **Tailwind CSS** (custom design system without Material UI). Features **Redux Toolkit** and WebSockets for real-time incident updates.
*   **Data & Storage:** **GraphQL** (BFF pattern) for aggregated dashboard reporting; **Amazon S3** for storing postmortem evidence (logs/screenshots).
*   **DevOps:** Integrated **Grafana** for monitoring business metrics (MTTR/MTTA) and **Vitest** for unit/integration testing. Secure access via **OAuth 2.0/JWT**.
