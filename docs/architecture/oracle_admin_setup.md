# Configuración manual de OCI para el administrador

Esta guía contiene únicamente acciones que debe realizar un administrador en la consola
de Oracle Cloud antes de ejecutar Terraform desde GitHub Actions. No copies claves
privadas, OCIDs ni tokens a archivos versionados, comentarios de PR o chat.

## 1. Seleccionar región y crear compartimento

1. En la barra superior de OCI, selecciona la región **Chile Central
   (`sa-santiago-1`)**. Todos los recursos regionales deben crearse en esta región.
2. Abre **Identity & Security > Compartments**.
3. Selecciona el compartment padre deseado (para un MVP puede ser el root compartment
   de la tenancy).
4. Pulsa **Create Compartment** y completa:
   - **Name:** `cmp-reciclaje-mvp`
   - **Description:** `Recycling Logistics MVP production infrastructure`
5. Crea el compartment y abre su detalle.
6. Copia su OCID: será `OCI_COMPARTMENT_OCID`.

No crees a mano VCN, subnet, instancia ni reglas de red: Terraform las administra.

## 2. Generar API signing key para Terraform

1. Pulsa el icono de perfil y abre **User settings**.
2. En **Resources**, abre **API Keys** y pulsa **Add API Key**.
3. Selecciona **Generate API Key Pair** y descarga la clave privada PEM.
4. Guarda el archivo PEM en un gestor de secretos local seguro; no lo subas a GitHub,
   no lo copies al repositorio y no lo envíes por chat.
5. Confirma la creación. OCI mostrará el fingerprint de la clave.
6. Copia el fingerprint: será el valor de `OCI_API_KEY_FINGERPRINT`.

La clave debe pertenecer al usuario que ejecutará Terraform. Ese usuario necesita
políticas OCI para administrar recursos de red, cómputo y Object Storage dentro de
`cmp-reciclaje-mvp`.

## 3. Copiar identificadores requeridos

| Valor | Dónde obtenerlo en OCI | Destino |
|---|---|---|
| Tenancy OCID | Perfil > **Tenancy** > OCID | `OCI_TENANCY_OCID` |
| User OCID | Perfil > **User settings** > OCID | `OCI_USER_OCID` |
| Compartment OCID | **Identity & Security > Compartments** > `cmp-reciclaje-mvp` > OCID | `OCI_COMPARTMENT_OCID` |
| API key fingerprint | **User settings > API Keys** > clave creada | `OCI_API_KEY_FINGERPRINT` |
| API private key | Archivo PEM descargado en el paso 2 | `OCI_API_PRIVATE_KEY` |

Los nombres conceptuales `OCI_FINGERPRINT` y `OCI_PRIVATE_KEY` solicitados en algunos
materiales de referencia corresponden, respectivamente, a
`OCI_API_KEY_FINGERPRINT` y `OCI_API_PRIVATE_KEY`. El workflow actual usa los nombres
con prefijo `API`; configura esos nombres exactos para que Terraform los reciba.

## 4. Crear una llave SSH dedicada

En una terminal local confiable, fuera de cualquier repositorio:

```bash
ssh-keygen -t ed25519 -C "deploy@recycling-logistics" \
  -f ~/.ssh/recycling-logistics-deploy -N ""
```

- El contenido de `~/.ssh/recycling-logistics-deploy.pub` será
  `DEPLOY_SSH_PUBLIC_KEY` (GitHub Environment variable). Terraform lo instala en la
  instancia.
- El contenido completo de `~/.ssh/recycling-logistics-deploy` será
  `SSH_PRIVATE_KEY` del Environment de producción, usado por `deploy.yml`. La misma
  clave se conserva en la estación administrativa para el despliegue local de test
  mediante `scripts/deploy-test-api.sh`; un futuro runner self-hosted debe usar una
  credencial distinta y limitada.
- No reutilices una llave SSH personal ni compartas el archivo privado.

## 5. Bootstrap del estado remoto de Terraform

GitHub-hosted runners no conservan state local. Crea una vez el backend antes del
primer `plan` autenticado:

1. Abre **Storage > Object Storage & Archive Storage > Buckets** y selecciona
   `cmp-reciclaje-mvp`.
2. Crea un bucket **privado Standard**, por ejemplo `recycling-tfstate`.
3. Copia el Object Storage namespace, visible en la misma página.
4. En **User settings > Customer Secret Keys**, genera una clave.
5. Guarda el Access Key y Secret Key; OCI muestra el secreto solo una vez.

## 6. Configurar GitHub Actions

En `DungeonEaters/recycling-infra`, abre **Settings > Environments > production**.
El Environment ya debe exigir aprobación y limitar despliegues a `main`.

### Secrets

| Secret | Valor |
|---|---|
| `OCI_TENANCY_OCID` | Tenancy OCID. |
| `OCI_USER_OCID` | User OCID del usuario con API key. |
| `OCI_API_KEY_FINGERPRINT` | Fingerprint de la API key (`OCI_FINGERPRINT` en nomenclatura conceptual). |
| `OCI_API_PRIVATE_KEY` | PEM completo (`OCI_PRIVATE_KEY` en nomenclatura conceptual). |
| `OCI_STATE_S3_ACCESS_KEY` | Customer Secret Key access key de Object Storage. |
| `OCI_STATE_S3_SECRET_KEY` | Customer Secret Key secret de Object Storage. |
| `SSH_PRIVATE_KEY` | Llave SSH privada dedicada de despliegue. |

### Variables

| Variable | Valor |
|---|---|
| `OCI_REGION` | `sa-santiago-1`. |
| `OCI_COMPARTMENT_OCID` | OCID de `cmp-reciclaje-mvp`. |
| `OCI_AVAILABILITY_DOMAIN` | Nombre literal de un AD de `sa-santiago-1` con capacidad A1. |
| `OCI_UBUNTU_IMAGE_OCID` | OCID regional de Ubuntu LTS ARM64. |
| `DEPLOY_SSH_PUBLIC_KEY` | Llave pública SSH dedicada. |
| `ADMIN_CIDRS` | Lista JSON de IPs administrativas, por ejemplo `["198.51.100.42/32"]`. |
| `OCI_STATE_BUCKET` | Nombre del bucket privado de state. |
| `OCI_STATE_NAMESPACE` | Namespace de Object Storage. |

Después del primer apply, registra una host key verificada para la IP pública de la VM
en la estación administrativa. Para el deploy local de test, el PAT de GHCR con
`read:packages` se introduce interactivamente cuando
`scripts/deploy-test-api.sh --image-tag <tag>` lo solicita; no se guarda en state,
archivos de proyecto ni argumentos de comandos.

## 7. Verificación antes de aplicar

1. Confirma que el usuario OCI tiene permisos en `cmp-reciclaje-mvp`.
2. Confirma que existe capacidad para `VM.Standard.A1.Flex` (4 OCPU, 24 GB) en el AD
   elegido. La capacidad A1 puede agotarse; prueba otro AD si OCI rechaza la creación.
3. Ejecuta manualmente **Terraform plan** en GitHub Actions y revisa el plan.
4. Solo si el plan es esperado, ejecuta **Terraform apply** desde `main`, escribe
   `APPLY` y aprueba el Environment `production`.
5. No ejecutes `terraform destroy` ni borres el bucket de state como parte de un
   troubleshooting normal.
