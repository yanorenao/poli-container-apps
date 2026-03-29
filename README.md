# CrediRápido - poli-container-apps

Este repositorio contiene la configuración de infraestructura como código (IaC) para la arquitectura de la startup Fintech **CrediRápido**, desplegada en Microsoft Azure utilizando [Terraform](https://www.terraform.io/). 

La solución se centra en la provisión de servicios PaaS y Serverless para lograr un excelente *time-to-market*, eficiencia en costos y alta seguridad mediante automatización y políticas de gobernanza rigurosas.

---

## 🏗️ Estructura del Repositorio

Los archivos principales de la configuración de Terraform se encuentran ubicados en la raíz del repositorio:

*   `main.tf`: Declaración principal de los recursos de la infraestructura.
*   `variables.tf`: Definición de variables parametrizadas para instanciar distintos entornos (ej. `dev`, `prod`) de forma independiente desde una misma base de código.
*   `outputs.tf`: Valores de salida generados al aprovisionar la infraestructura.
*   `.github/workflows/deploy.yml`: Pipeline de despliegue continuo mediante GitHub Actions.

## 🚀 Arquitectura y Tecnologías

La arquitectura diseñada aprovecha los servicios administrados de Azure para crear un ecosistema seguro, escalable y resiliente:

*   **Azure Container Apps**: Motor de contenedores serverless para un rápido despliegue de microservicios.
*   **Azure Database for PostgreSQL (Flexible Server)**: Base de datos relacional orientada a cumplir con la integridad transaccional del negocio.
*   **Azure Key Vault**: Gestión centralizada y segura de secretos, contraseñas, cadenas de conexión y certificados.
*   **Azure Virtual Network**: Aislamiento y segmentación de servicios críticos utilizando *Private Endpoints* y zonas de DNS privadas para evitar su exposición directa a Internet público.

## 🔒 Seguridad y Gobernanza

Nuestra arquitectura implementa estándares de **Defensa en Profundidad** y el principio de **Mínimo Privilegio (PoLP)**:

*   **Identidades Administradas (Managed Identities)**: Uso de identidades del tipo `SystemAssigned`, lo que elimina la necesidad de manejar credenciales estáticas dentro del código y reduce riesgos de filtración.
*   **Control de Acceso Basado en Roles (RBAC)**: Asignación de permisos precisos (por ejemplo, el rol `Key Vault Secrets User`) para restringir el alcance del acceso únicamente a los componentes autorizados que realmente lo requieran.
*   **Estado de Terraform e Idempotencia**: La configuración emplea un backend remoto (`azurerm`) para almacenar el estado en la nube. Esto garantiza que las operaciones repetidas produzcan los mismos resultados de forma controlada y se proteja el entorno de cambios inesperados.

## ⚙️ Integración y Despliegue Continuo (CI/CD)

Empleamos la metodología de *Docs-as-code* y *GitOps* para asegurar la fiabilidad y el control de todos los cambios de infraestructura. El proceso automatizado establece un mecanismo de entrega robusto:

1.  **Validación (Pull Request)**: Al enviar un PR, se ejecutan etapas de autoformato de código (`terraform fmt`), análisis estático en busca de vulnerabilidades (`tfsec`), inicialización y validación formal de configuración. Como resultado final se produce un plan (`terraform plan`), inyectando su salida como comentario dentro de GitHub.
2.  **Despliegue a Producción (Merge to Main)**: Posterior a una revisión rigurosa y aprobación del código (Merge), se requiere la autorización manual en el entorno de despliegue antes de que los recursos sean efectivamente aprovisionados y modificados en la suscripción de Azure (`terraform apply`).

## ⚖️ Trade-offs Arquitectónicos y Riesgos Técnicos

### Ventajas (Trade-offs Positivos)
*   Excepcional *time-to-market* gracias al uso de abstracciones Serverless/PaaS.
*   Escalado ágil sin la necesidad del costoso y complejo pre-aprovisionamiento de clusters.
*   La automatización de despliegue mitiga drásticamente las fallas por error humano.

### Desafíos y Riesgos (Trade-offs Negativos)
*   **Vendor Lock-In**: Alta dependencia del ecosistema de Azure, encareciendo teóricas migraciones a AWS o GCP en el futuro si se compara con usar Kubernetes directamente.
*   **Telemetría Limitada**: La observabilidad entre los servicios PaaS puede requerir configuraciones avanzadas a través de Log Analytics, siendo menos transparente que un esquema IaaS tradicional.
*   Escalamiento no controlado por eventuales picos impredecibles de carga que podrían desembocar en aumentos súbitos en la facturación.
*   Vulnerabilidad potencial a ataques DDoS directamente al *endpoint* del API expuesto.

## 🔮 Visión de Evolución del Proyecto

A medida que la startup crezca y requiera una arquitectura más avanzada con nuevos microservicios, eventos asíncronos y multirregiones, sería natural evaluar las siguientes evoluciones:

*   **Migración a Azure Kubernetes Service (AKS)**: Incorporación de service meshes (ej. Istio) y autoscaling complejo (HPA, KEDA, etc.).
*   **Introducción de Mensajería**: Herramientas como Azure Service Bus, Event Hubs (para flujos de scoring) o Event Grid, mejorando el desacoplamiento y resiliencia general del sistema frente a alto tráfico financiero.
*   **Identidad Externa**: Integración con Azure AD B2C para login federado o autenticación multi-factor con los clientes bancarios.