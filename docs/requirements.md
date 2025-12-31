
# Требования

## 1. Общее описание
**InOps** — это платформа управления инцидентами для IT-команд. Система агрегирует уведомления (алерты) от систем мониторинга (Prometheus, Zabbix, AWS CloudWatch), группирует их, фильтрует дубликаты и оповещает ответственных инженеров согласно расписанию дежурств (On-call rotation).

**Цель проекта:** Создать отказоустойчивую микросервисную систему с высокой реактивностью (Real-time) и удобным интерфейсом для оперативного реагирования на сбои.

---

## 2. Архитектура системы (High-Level Design)

Система строится на базе микросервисной архитектуры. Взаимодействие между сервисами происходит асинхронно (через брокер сообщений) или синхронно (REST/Feign) в зависимости от критичности операции.

### 2.1. Стек технологий
*   **Backend:** Java 25, Spring Boot 4, Spring Cloud (Gateway, Config).
*   **Databases:** PostgreSQL, MongoDB, Redis.
*   **Storage:** ???
*   **Frontend:** React, Vite, TypeScript, Tailwind CSS, Redux Toolkit, Headless UI.
*   **API:** REST (для интеграций и простых CRUD), GraphQL (для сложных выборок на UI).
*   **Security:** Spring Security, OAuth 2.0 / JWT.
*   **Testing:** JUnit 5, Mockito (Backend); Vitest, React Testing Library (Frontend).
*   **Monitoring:** Grafana, Prometheus, Micrometer.

---

## 3. Описание Микросервисов (Backend)

### 1. API Gateway & Auth Service
*   **Роль:** Единая точка входа. Маршрутизация запросов, проверка JWT токенов.
*   **Технологии:** Spring Cloud Gateway, Spring Security.
*   **Функции:**
    *   Регистрация/Вход (OAuth 2.0: GitHub/Google).
    *   Выдача и валидация JWT (Access + Refresh tokens).
    *   Rate Limiting (через Redis), чтобы API не «завалили» алертами.

### 2. Alert Ingestion Service (Сервис приема алертов)
*   **Роль:** Принимает «сырые» данные от мониторинга.
*   **База данных:** MongoDB (для сырых JSON), Redis (для дедупликации).
*   **Логика:**
    1.  Принимает POST запрос (REST) от Prometheus.
    2.  Генерирует уникальный хеш алерта (Fingerprint).
    3.  **Redis:** Проверяет, был ли такой алерт за последние 15 минут.
        *   *Если был:* увеличивает счетчик `occurrence_count` (дедупликация).
        *   *Если нет:* создает новый инцидент, сохраняет payload в **MongoDB** и отправляет событие `incident.created` в очередь.

### 3. Policy & Schedule Service (Сервис расписаний)
*   **Роль:** Определяет, *кто* должен реагировать на алерт прямо сейчас.
*   **База данных:** PostgreSQL.
*   **Логика:**
    *   Управление командами и пользователями.
    *   Календарь дежурств (слои: Primary, Secondary).
    *   Escalation Policies: «Если Primary не ответил за 5 мин -> звонить Secondary -> через 10 мин -> менеджеру».
    *   Использование ACID транзакций Postgres для гарантии целостности расписания.

### 4. Notification Service (Сервис уведомлений)
*   **Роль:** Отправка сообщений во внешний мир.
*   **Технологии:** Интеграция с SMTP (Email), Slack Webhooks, Telegram API.
*   **Логика:** Слушает события о новых инцидентах и рассылает уведомления конкретным юзерам, полученным от Schedule Service.

### 5. Postmortem & File Service (???)
*   **Роль:** Работа с разборами полетов и файлами.
*   **Хранилище:** Amazon S3.
*   **Логика:**
    *   Загрузка логов и скриншотов, прикрепленных к инциденту (Presigned URLs).
    *   CRUD для отчетов Postmortem (Markdown).

---

## 4. (NOT DONE) База данных и хранение (Data Layer)

### PostgreSQL (Реляционные данные)
Используется для структур, требующих строгой схемы и связей:
*   `users`, `teams`
*   `schedules` (расписания)
*   `escalation_policies`
*   `incidents` (основные метаданные: статус, ID ответственного, время начала).

### MongoDB (Документоориентированные данные)
*   `alert_payloads`: Полный JSON, пришедший от Prometheus (может менять структуру).
*   `audit_logs`: История всех действий («Вася нажал Ack», «Система отправила Email»).

### Redis (In-Memory)
*   **Deduplication:** Ключ `alert:{hash}`, TTL = 15 минут.
*   **Real-time stats:** Счетчики «Открытых инцидентов» для быстрого отображения на дашборде.
*   **User Sessions:** Хранение Refresh токенов.

---

## 5. Frontend Архитектура (Vite + React)

Вместо готовой UI-библиотеки (MUI) используется подход **Headless + Utility CSS**.

### 5.1. Дизайн-система (Tailwind CSS)
*   Реализация **Dark Mode** (через класс `dark` в Tailwind), так как инженеры часто работают ночью.
*   Цветовое кодирование критичности: `bg-red-500` (Critical), `bg-yellow-400` (Warning).

### 5.2. Состояние (Redux Toolkit)
*   `incidentsSlice`: Список активных инцидентов. Использует `createEntityAdapter` для нормализации данных.
*   `websocketMiddleware`: Кастомный middleware для обработки WS-сообщений. При получении события `INCIDENT_NEW` автоматически обновляет Redux Store (RTK Query `updateQueryData`).

### 5.3. API Layer (REST + GraphQL)
*   **REST Client (Axios):** Для действий (Action): «Взять в работу» (`POST /incidents/{id}/ack`), «Разрешить» (`POST /resolve`), Загрузка файлов.
*   **GraphQL (Apollo Client / Urql):** Для **Dashboard View**. Одним запросом забираем:
    ```graphql
    query GetDashboardData {
      myProfile { name }
      activeIncidents(status: OPEN) { id, title, severity }
      currentOnCall { teamName, engineer { name } }
      stats(period: "1h") { totalAlerts }
    }
    ```

### 5.4. Тестирование (Vitest)
*   Unit-тесты для утилит (форматирование времени, парсинг логов).
*   Интеграционные тесты (RTL) для компонента `IncidentList`: проверка, что при приходе нового алерта список обновляется без перезагрузки.

---

## 6. Мониторинг и Observability (Grafana)

В этом проекте Grafana используется в двух ипостасях:

1.  **Инфраструктурный мониторинг (для разработчика):**
    *   Spring Boot Actuator экспортирует метрики в Prometheus формате.
    *   Grafana строит графики: CPU, RAM, Latency микросервисов, кол-во ошибок 500.

2.  **Продуктовая аналитика (часть фичи):**
    *   В PostgreSQL создается view для аналитики.
    *   Grafana подключается к PostgreSQL как к источнику данных.
    *   Строятся графики: **MTTA** (Mean Time To Acknowledge) и **MTTR** (Mean Time To Resolve).
    *   **Embed:** Графики встраиваются в Frontend через `<iframe>` или (продвинутый вариант) Frontend сам рисует графики на Chart.js/Recharts, получая агрегированные данные от Backend API. *Рекомендую второй вариант для чистоты React-кода, а Grafana оставить для админов.*

---

## 7. Этапы разработки (Roadmap)

### Этап 1: Core Backend & Ingestion
1.  Поднять Docker Compose (Postgres, Mongo, Redis).
2.  Написать `Alert Service`. Реализовать REST Endpoint для приема JSON.
3.  Реализовать логику дедупликации в Redis.

### Этап 2: Пользователи и Расписания
1.  Написать `Auth Service` (JWT).
2.  Написать `Schedule Service`. Создать простые CRUD для пользователей и команд.
3.  Связать Алерты с расписанием (Assign alert to user).

### Этап 3: Frontend MVP
1.  Настроить Vite + Tailwind.
2.  Сверстать страницу списка инцидентов (Login + List).
3.  Подключить получение данных через GraphQL.

### Этап 4: Real-time и Действия
1.  Добавить WebSocket (Spring WebSocket + STOMP).
2.  Реализовать кнопки "Ack" / "Resolve" на фронтенде.
3.  Обновление интерфейса в реальном времени.

### Этап 5: Файлы и Аналитика
1.  Подключить MinIO (S3 mock).
2.  Реализовать загрузку скриншотов.
3.  Настроить сбор метрик и дашборд в Grafana.
4.  Написать тесты (Vitest + JUnit).

---

## 8. Пример API контракта

**POST /api/v1/alerts (Ingestion)**
```json
{
  "source": "Prometheus",
  "severity": "critical",
  "description": "High CPU load on server-db-01",
  "details": { "cpu": "99%", "region": "us-east-1" } // Сохранится в Mongo
}
```

**GraphQL Query (Dashboard)**
```graphql
type Incident {
  id: ID!
  status: String!
  assignee: User
  payload: JSON # Из Mongo
  createdAt: String!
}
```