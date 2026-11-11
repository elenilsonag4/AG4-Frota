# Gestão de Frota

Aplicativo web responsivo baseado na especificação visual fornecida. O menu inferior é **horizontalmente rolável** em telas móveis e mantém os itens em largura própria (não comprime os módulos).

## O que já funciona no modo demonstração

- Login local e sessão na aba do navegador.
- Cadastro, consulta, edição e exclusão de veículos, motoristas, abastecimentos, manutenção, estoque, lançamentos financeiros e usuários.
- Motoristas com exatamente cinco informações: nome, telefone, categoria da CNH, vencimento e status calculado automaticamente.
- Status da CNH: Regular a partir de 90 dias restantes; alerta quando faltarem menos de 90 dias; vencida após a data final.
- Ícones de edição e exclusão em SVG separados (`img/lap.svg` e `img/lix.svg`).
- Indicadores na página inicial, alertas de estoque baixo, vencimento de CNH e manutenção pendente.
- Atualização da quilometragem do veículo ao lançar abastecimento/manutenção.
- Relatórios consolidados, exportação CSV e impressão/salvamento em PDF pelo navegador.
- Cinco níveis de acesso: Leitor, Motorista, Alimentador, Gerenciador e Administrador.
- Armazenamento local no navegador via `localStorage` para testes.

## Acesso de demonstração

- E-mail: `admin@frota.com`
- Senha: `admin123`

Os dados demonstrativos ficam no navegador/dispositivo em que o sistema for aberto. Use o botão Sair para encerrar a sessão. Para reiniciar a base de demonstração, execute no console do navegador: `localStorage.removeItem('frota_db')` e recarregue.

## Executar localmente

Abra `index.html` em um navegador ou sirva a pasta com um servidor estático (por exemplo, VS Code Live Server). O modo demonstração não exige servidor.

## Preparar Supabase

1. Crie um projeto no Supabase.
2. No SQL Editor, execute `sql/schema.sql`.
3. Em Authentication, configure os provedores e crie o primeiro usuário administrador.
4. Ajuste o perfil desse usuário para `Administrador` na tabela `profiles`.
5. Copie `config.example.js` para `config.js` e informe `Project URL` e `anon/public key`.
6. Publique a pasta em uma hospedagem HTTPS.

**Importante:** o modo local atual é para demonstração e testes de interface/fluxos. Não armazene dados reais ou senhas reais nele. O cliente Supabase é inicializado quando a configuração existe, mas a sincronização CRUD/autenticação remota precisa ser ligada à camada de dados antes de usar em produção. Nunca exponha a chave `service_role` no navegador. O SQL inclui tabelas relacionais, trigger de perfil e políticas RLS por função; revise as regras com os responsáveis pela segurança antes da publicação.

## Estrutura

- `index.html`: estrutura e telas-base.
- `style.css`: identidade visual responsiva.
- `app.js`: navegação, formulários, regras e persistência local.
- `sql/schema.sql`: estrutura de dados e políticas Supabase.
- `config.example.js`: modelo de configuração remota.
