# Pipeline CI/CD com GitHub Actions e Terraform na AWS

Projeto acadêmico da Atividade 3/4: provisionamento de VPC, EC2, Application Load Balancer e RDS MySQL na AWS usando Terraform e implantação automatizada pelo GitHub Actions.

## 1. Arquitetura

- VPC `10.0.0.0/16`.
- Duas sub-redes públicas em zonas de disponibilidade distintas.
- Duas sub-redes privadas para o banco de dados.
- EC2 Amazon Linux 2023 com Nginx.
- Application Load Balancer público na porta 80.
- RDS MySQL criptografado, sem acesso público.
- Security Groups limitando o tráfego: Internet → ALB → EC2 → RDS.
- State remoto no Amazon S3, com versionamento, criptografia e lockfile nativo do Terraform.

> Observação: para manter o custo do laboratório menor, a EC2 fica em uma sub-rede pública, mas seu Security Group aceita HTTP somente do ALB. O RDS permanece em sub-redes privadas. Não foi criado NAT Gateway.

## 2. Estrutura do repositório

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yml
├── terraform/
│   ├── main.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── variables.tf
│   └── versions.tf
├── scripts/
│   └── create-state-bucket.sh
├── .gitignore
└── README.md
```

## 3. Pré-requisitos

- Conta AWS com permissões para criar VPC, EC2, ELB e RDS.
- AWS CLI instalado e configurado localmente para a preparação inicial.
- Terraform 1.10 ou superior.
- Repositório GitHub.
- Nome globalmente único para o bucket S3 de state.

## 4. Preparar o state remoto

O bucket S3 precisa existir antes do primeiro `terraform init`. Na sua máquina, execute:

```bash
chmod +x scripts/create-state-bucket.sh
./scripts/create-state-bucket.sh meu-bucket-terraform-unico sa-east-1
```

Use um nome exclusivo no lugar de `meu-bucket-terraform-unico`. O script habilita bloqueio de acesso público, versionamento e criptografia no bucket.

O workflow usa `use_lockfile=true`, recurso de lock nativo do backend S3 em versões atuais do Terraform. A role usada pelo pipeline precisa ter acesso ao bucket e aos objetos de state, incluindo leitura, gravação e exclusão do arquivo de lock.

## 5. Configurar autenticação OIDC na AWS

A autenticação OIDC evita guardar `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` no GitHub.

1. No IAM da AWS, cadastre o provedor de identidade OpenID Connect:
   - URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
2. Crie uma IAM Role para o GitHub Actions.
3. Configure a política de confiança (substitua `USUARIO_OU_ORGANIZACAO` e `NOME_DO_REPOSITORIO`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ID_DA_CONTA_AWS:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:USUARIO_OU_ORGANIZACAO/NOME_DO_REPOSITORIO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Para validar Pull Requests de branches do mesmo repositório, a confiança pode incluir também o subject `repo:USUARIO_OU_ORGANIZACAO/NOME_DO_REPOSITORIO:pull_request`. Não permita esse acesso indiscriminadamente a repositórios não confiáveis.

4. Conceda à role as permissões necessárias para criar e gerenciar os recursos deste projeto (EC2/VPC, Elastic Load Balancing, RDS) e para acessar o bucket S3 do state. Para um laboratório, uma política gerenciada ampla pode facilitar o teste, mas o ideal é criar uma política de menor privilégio, limitada aos recursos e ações necessários. Não use credenciais de administrador permanentes.

## 6. Configurar GitHub Secrets e Variables

No repositório, acesse **Settings → Secrets and variables → Actions**.

### Secrets

| Nome | Valor |
|---|---|
| `AWS_ROLE_ARN` | ARN da IAM Role criada para OIDC |
| `TF_VAR_DB_PASSWORD` | Senha forte para o usuário do banco RDS |

### Variables

| Nome | Valor de exemplo |
|---|---|
| `AWS_REGION` | `sa-east-1` |
| `TF_STATE_BUCKET` | Nome do bucket S3 criado |
| `TF_VAR_DB_USERNAME` | `admin` |

Não coloque senhas, chaves ou arquivos `terraform.tfvars` no Git. O arquivo `.gitignore` já exclui arquivos de state e variáveis locais.

## 7. Como o pipeline funciona

O arquivo `.github/workflows/deploy.yml` define o processo:

1. **Checkout:** baixa o código versionado.
2. **Setup Terraform:** instala a versão definida no workflow.
3. **Credenciais OIDC:** assume a IAM Role da AWS usando token temporário.
4. **Terraform Init:** inicializa os providers e conecta ao state remoto S3.
5. **Terraform Format:** verifica a formatação.
6. **Terraform Validate:** valida a configuração.
7. **Terraform Plan:** apresenta as alterações previstas e salva o log como artifact.
8. **Terraform Apply:** aplica as alterações somente em `push` para `main`.

### Eventos

- Pull Request direcionado à `main`: executa validação e plan, sem aplicar mudanças.
- Push na `main`: executa validação, plan e apply.
- `workflow_dispatch`: permite iniciar manualmente pela aba Actions; o apply só ocorre se o evento for push na main.

Os logs ficam em **GitHub → Actions → execução do workflow**. O artifact `terraform-plan-*` contém o log textual do plano e fica disponível por cinco dias. O arquivo de state fica no S3.

## 8. Enviar o projeto ao GitHub

Na pasta do projeto:

```bash
git init
git add .
git commit -m "Adiciona infraestrutura Terraform e pipeline CI/CD"
git branch -M main
git remote add origin https://github.com/USUARIO/NOME-DO-REPOSITORIO.git
git push -u origin main
```

Substitua a URL pelo endereço do seu repositório.

Depois do push, abra a aba **Actions** no GitHub e acompanhe cada etapa do workflow.

## 9. Executar localmente (opcional)

Com AWS CLI configurado e as variáveis definidas:

```bash
export TF_VAR_db_password='SENHA_FORTE'
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

Ao terminar o teste, remova os recursos para evitar cobranças:

```bash
terraform -chdir=terraform destroy
```

O bucket S3 do state não é removido pelo `terraform destroy`, pois foi criado previamente. Só o exclua depois de confirmar que não precisa mais do state e de seus históricos.

## 10. Roteiro sugerido para o vídeo

1. Apresente o repositório público e sua estrutura de pastas.
2. Mostre os arquivos Terraform e explique VPC, sub-redes, EC2, ALB, RDS e Security Groups.
3. Mostre o workflow `deploy.yml`, destacando OIDC e as etapas init, plan e apply.
4. Abra a aba Actions e acompanhe os logs de uma execução concluída.
5. Na AWS, mostre os recursos criados e a URL do ALB funcionando.
6. Explique que o state fica no S3 e que o plano é salvo como artifact no GitHub.

**Importante:** não exiba valores de Secrets, senha do banco, tokens ou dados sensíveis no vídeo. A criação de EC2, ALB e RDS pode gerar custos. Faça o teste em uma conta autorizada e execute `terraform destroy` ao finalizar a demonstração.
