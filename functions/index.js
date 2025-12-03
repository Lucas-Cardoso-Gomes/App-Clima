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
 * Função chamável (Callable) para excluir um usuário diretamente do app.
 * Exclui do Auth e do Firestore.
 */
exports.deleteUser = functions.https.onCall(async (data, context) => {
  // Verifica se o usuário está autenticado
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "O usuário deve estar logado para chamar esta função."
    );
  }

  const uid = data.uid;
  if (!uid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "O argumento 'uid' é obrigatório."
    );
  }

  try {
    console.log(`Solicitação de exclusão para o usuário: ${uid}`);

    // 1. Excluir do Firebase Authentication
    await admin.auth().deleteUser(uid);
    console.log(`Usuário ${uid} excluído do Auth.`);

    // 2. Excluir do Firestore (isso pode disparar o trigger deleteAuthUser, mas ele lida com usuário inexistente)
    await admin.firestore().collection("usuarios").doc(uid).delete();
    console.log(`Documento do usuário ${uid} excluído do Firestore.`);

    return { success: true, message: "Usuário excluído com sucesso." };
  } catch (error) {
    console.error("Erro ao excluir usuário:", error);
    throw new functions.https.HttpsError("internal", "Erro ao excluir usuário.", error);
  }
});
