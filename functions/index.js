const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Trigger que escuta a exclusão de documentos na coleção 'usuarios'.
 * Quando um usuário é removido do Firestore, ele também é removido do Firebase Auth.
 */
exports.deleteAuthUser = functions.firestore
    .document("usuarios/{userId}")
    .onDelete(async (snap, context) => {
      const userId = context.params.userId;
      console.log(`Iniciando exclusão do usuário ${userId} do Firebase Auth...`);

      try {
        await admin.auth().deleteUser(userId);
        console.log(`Sucesso: Usuário ${userId} removido do Firebase Auth.`);
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
            console.log(`Usuário ${userId} não encontrado no Auth (já deletado?).`);
            return;
        }
        console.error(`Erro ao remover usuário ${userId} do Firebase Auth:`, error);
      }
    });
