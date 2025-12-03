# app_clima

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Cloud Functions

Para garantir que ao apagar um usuário do Firestore, ele também seja apagado do Firebase Auth, foi implementada uma Cloud Function.

### Configuração e Deploy

1. Certifique-se de ter o [Firebase CLI](https://firebase.google.com/docs/cli) instalado e estar logado (`firebase login`).
2. Navegue até a pasta `functions` e instale as dependências:
   ```bash
   cd functions
   npm install
   cd ..
   ```
3. Faça o deploy da função para o Firebase:
   ```bash
   firebase deploy --only functions
   ```

A função `deleteAuthUser` será acionada automaticamente sempre que um documento for excluído da coleção `usuarios` no Firestore.

Além disso, foi implementada uma função `deleteUser` que pode ser chamada diretamente pelo aplicativo. Para que a exclusão funcione corretamente a partir do botão "Excluir" no app, é **obrigatório** fazer o deploy dessas funções.
