import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @State private var name = ""
    @State private var phone = ""
    @State private var showingDelete = false

    var body: some View {
        Form {
            Section {
                TextField("Имя", text: $name)
                    .textContentType(.name)
                TextField("+79000000000", text: $phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                Button("Сохранить") {
                    Task { _ = await store.saveProfile(name: name, phone: normalizedPhone) }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || normalizedPhone.count != 12)
            } header: {
                Text("Данные для бронирования")
            } footer: {
                Text("Имя и телефон хранятся в зашифрованном виде и передаются магазину только для исполнения брони.")
            }

            Section("Документы") {
                NavigationLink("Политика обработки данных") {
                    LegalTextView(title: "Политика обработки данных", text: LegalCopy.privacy)
                }
                NavigationLink("Согласие на обработку данных") {
                    LegalTextView(title: "Согласие", text: LegalCopy.consent)
                }
                NavigationLink("Правила бронирования") {
                    LegalTextView(title: "Правила бронирования", text: LegalCopy.reservation)
                }
            }

            Section {
                Button("Удалить аккаунт и данные", role: .destructive) { showingDelete = true }
            } footer: {
                Text("Удаление обезличивает профиль. Документы по завершённым операциям могут храниться в сроки, установленные законом.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColor.paper)
        .navigationTitle("Профиль")
        .onAppear {
            name = store.profile?.name ?? ""
            phone = store.profile?.phone ?? ""
        }
        .confirmationDialog("Удалить аккаунт?", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("Удалить безвозвратно", role: .destructive) {
                Task {
                    if await store.deleteAccount() {
                        name = ""
                        phone = ""
                    }
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Избранное и активные пользовательские данные будут удалены или обезличены.")
        }
    }

    private var normalizedPhone: String {
        let digits = phone.filter(\.isNumber)
        if digits.count == 11, digits.first == "8" { return "+7" + String(digits.dropFirst()) }
        if digits.count == 11, digits.first == "7" { return "+" + digits }
        return phone.hasPrefix("+") ? "+" + digits : digits
    }
}

private struct LegalTextView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum LegalCopy {
    static let privacy = """
    Рабочая версия для тестового контура.

    Оператор, цели, состав данных, сроки хранения, перечень обработчиков и адрес инфраструктуры должны быть заполнены юридическим лицом до публикации приложения. Актуальная утверждённая редакция должна загружаться с российского домена оператора с фиксацией версии согласия.
    """

    static let consent = """
    Согласие должно быть конкретным, предметным, информированным, сознательным и однозначным. В продуктивной версии пользователь отдельно подтверждает обработку имени, телефона, геопозиции и передачу выбранному магазину для исполнения брони. Отзыв согласия доступен из профиля.
    """

    static let reservation = """
    Бронь не является онлайн-оплатой. Товар резервируется на 2 часа после подтверждения магазином. Оплата и выдача происходят в магазине. Итоговое наличие подтверждает продавец.
    """
}
