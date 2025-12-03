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
        // Se o erro for 'auth/user-not-found', significa que já foi deletado ou não existe.
        if (error.code === 'auth/user-not-found') {
            console.log(`Usuário ${userId} não encontrado no Auth (já deletado?).`);
            return;
        }
        console.error(`Erro ao remover usuário ${userId} do Firebase Auth:`, error);
      }
    });

/**
 * Função Callable para excluir um usuário manualmente do App.
 * Recebe { uid: string } e remove do Auth e do Firestore.
 */
exports.deleteUser = functions.https.onCall(async (data, context) => {
  // Verificar se o usuário está autenticado
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'O usuário deve estar logado para chamar esta função.'
    );
  }

  const uidToDelete = data.uid;
  if (!uidToDelete) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'O UID do usuário a ser excluído é obrigatório.'
    );
  }

  console.log(`Solicitação de exclusão para o usuário: ${uidToDelete} feita por ${context.auth.uid}`);

  try {
    // 1. Apagar do Firebase Auth
    await admin.auth().deleteUser(uidToDelete);
    console.log(`Usuário ${uidToDelete} removido do Auth.`);

    // 2. Apagar do Firestore (caso a trigger falhe ou para garantir)
    // Nota: Se a trigger deleteAuthUser estiver ativa, ela vai rodar quando fizermos esse delete.
    // Mas o deleteUser acima já removeu do Auth. A trigger vai tentar remover de novo e cair no catch 'user-not-found', o que é ok.
    await admin.firestore().collection('usuarios').doc(uidToDelete).delete();
    console.log(`Documento do usuário ${uidToDelete} removido do Firestore.`);

    return { success: true, message: `Usuário ${uidToDelete} excluído com sucesso.` };
  } catch (error) {
    console.error("Erro ao excluir usuário:", error);
    // Se falhar ao apagar do Auth (ex: user not found), tentamos apagar do Firestore mesmo assim?
    // Melhor retornar erro para o cliente saber.
    throw new functions.https.HttpsError('internal', 'Erro ao excluir usuário: ' + error.message);
  }
});
