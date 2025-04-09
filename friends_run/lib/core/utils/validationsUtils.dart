class ValidationUtils {
    static String? validateName(String? value) {
        if (value == null || value.isEmpty) {
            return "Digite seu nome completo";
        }

        if (!value.contains(" ")) {
            return "Digite seu nome completo";
        }

        final nameRegex = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ\s]+$");

        if (!nameRegex.hasMatch(value)) {
            return "O nome deve conter apenas letras e espaços";
        }

        return null;
    }

    static String? validateEmail(String? value) {
        if (value == null || value.isEmpty) return "Digite um email";
        final emailRegex =
        RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$');
        return emailRegex.hasMatch(value) ? null : "Email inválido";
    }

    static String? validatePassword(String? value) {
        if (value == null || value.isEmpty) return "Digite uma senha";
        if (value.length < 6) return "A senha deve ter pelo menos 6 caracteres";
        return null;
    }

    static String? validateConfirmPassword(String? value, String password) {
        if (value == null || value.isEmpty) return "Confirme sua senha";
        if (value != password) return "As senhas não coincidem";
        return null;
    }
}

