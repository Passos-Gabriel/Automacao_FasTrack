# ⚙️ Azure Resource Provisioning Automation

Este projeto é uma automação em PowerShell para provisionamento de ambientes na nuvem Microsoft Azure de forma padronizada, eficiente e segura.

## 🚀 Objetivo

Automatizar a criação de:

- Resource Groups
- Storage Accounts
- Key Vaults
- Service Principals (SPs)
- Grupos do Azure AD com diferentes permissões
- Atribuição de roles personalizadas por ambiente

Tudo com aplicação de tags corporativas, organização por ambiente (DEV, QAS, PRD) e com controle baseado em variáveis externas.

## 🔧 Tecnologias Utilizadas

- PowerShell
- Módulo `Az` do PowerShell
- Azure Active Directory (Azure AD)
- Azure Resource Manager (ARM)
- Azure CLI
- [Dotenv PowerShell Module](https://www.powershellgallery.com/packages/dotenv) (para carregar variáveis de ambiente)

## 📁 Estrutura

- `script.ps1`: Script principal de automação.
- `.env`: Arquivo com IDs das subscriptions (não incluído no repositório por segurança).
- `README.md`: Este arquivo.

## 📌 Pré-requisitos

- PowerShell 7+
- Azure CLI configurado e autenticado
- Permissões para criação de SPs, grupos AD e recursos
- Instalar os módulos necessários:

```powershell
Install-Module -Name Az -Scope CurrentUser -Force
Install-Module -Name dotenv -Scope CurrentUser -Force
