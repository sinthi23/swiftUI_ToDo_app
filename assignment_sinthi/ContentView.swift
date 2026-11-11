
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// MARK: - Todo Model

struct TodoItem: Identifiable {
    var id: String
    var title: String
    var isCompleted: Bool
}

// MARK: - Editor Route

struct EditorRoute: Identifiable {
    let id = UUID()
    let item: TodoItem?
}

// MARK: - Main Content View

struct ContentView: View {

    @State private var user: FirebaseAuth.User?
    @State private var authListener: AuthStateDidChangeListenerHandle?
    @State private var taskListener: ListenerRegistration?

    @State private var tasks: [TodoItem] = []
    @State private var editor: EditorRoute?

    private let db = Firestore.firestore()

    var body: some View {

        Group {
            if let user = user {
                todoScreen(user: user)
            } else {
                LoginView()
            }
        }
        .onAppear {
            authListener = Auth.auth().addStateDidChangeListener {
                _, newUser in

                user = newUser
                taskListener?.remove()
                taskListener = nil
                tasks = []

                if let newUser = newUser {
                    loadTasks(userID: newUser.uid)
                }
            }
        }
        .onDisappear {
            taskListener?.remove()

            if let authListener = authListener {
                Auth.auth().removeStateDidChangeListener(authListener)
            }
        }
        .sheet(item: $editor) { route in

            TodoEditorView(item: route.item) { title in

                saveTask(title: title, item: route.item)
            }
        }
    }

    // MARK: - Todo Screen

    func todoScreen(user: FirebaseAuth.User) -> some View {

        NavigationStack {

            VStack {

                if tasks.isEmpty {

                    Spacer()

                    Image(systemName: "checklist")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("No tasks yet!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Add your first task to get started.")
                        .foregroundColor(.secondary)

                    Spacer()

                } else {

                    List {

                        ForEach(tasks) { item in

                            HStack {

                                Button {
                                    toggleTask(item)
                                } label: {

                                    Image(systemName:
                                        item.isCompleted
                                        ? "checkmark.circle.fill"
                                        : "circle"
                                    )
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                }
                                .buttonStyle(.plain)

                                Text(item.title)
                                    .strikethrough(item.isCompleted)
                                    .foregroundColor(
                                        item.isCompleted
                                        ? .secondary
                                        : .primary
                                    )

                                Spacer()

                                // Edit Button

                                Button {
                                    editor = EditorRoute(item: item)
                                } label: {

                                    Image(systemName: "pencil")
                                        .foregroundColor(.orange)
                                }
                                .buttonStyle(.plain)

                                // Delete Button

                                Button(role: .destructive) {
                                    deleteTask(item)
                                } label: {

                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Todo List")
            .toolbar {

                ToolbarItem(placement: .topBarLeading) {

                    Button("Logout") {
                        try? Auth.auth().signOut()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {

                    Button {
                        editor = EditorRoute(item: nil)
                    } label: {

                        Image(systemName: "plus")
                            .font(.title2)
                    }
                }
            }
        }
    }

    // MARK: - Load Tasks

    func loadTasks(userID: String) {

        taskListener = db.collection("tasks")
            .whereField("userId", isEqualTo: userID)
            .addSnapshotListener { snapshot, error in

                if let error = error {
                    print("Error loading tasks: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    return
                }

                tasks = documents.map { document in

                    let data = document.data()

                    return TodoItem(
                        id: document.documentID,
                        title: data["title"] as? String ?? "",
                        isCompleted: data["isCompleted"] as? Bool ?? false
                    )
                }
            }
    }

    // MARK: - Add or Update Task

    func saveTask(title: String, item: TodoItem?) {

        guard let user = user else { return }

        let cleanTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanTitle.isEmpty else { return }

        if let item = item {

            // Update existing task

            db.collection("tasks")
                .document(item.id)
                .updateData([
                    "title": cleanTitle
                ]) { error in

                    if let error = error {
                        print("Update error: \(error.localizedDescription)")
                    }
                }

        } else {

            // Add new task

            db.collection("tasks")
                .addDocument(data: [
                    "title": cleanTitle,
                    "isCompleted": false,
                    "userId": user.uid,
                    "createdAt": Timestamp()
                ]) { error in

                    if let error = error {
                        print("Add error: \(error.localizedDescription)")
                    }
                }
        }
    }

    // MARK: - Delete Task

    func deleteTask(_ item: TodoItem) {

        db.collection("tasks")
            .document(item.id)
            .delete { error in

                if let error = error {
                    print("Delete error: \(error.localizedDescription)")
                }
            }
    }

    // MARK: - Complete Task

    func toggleTask(_ item: TodoItem) {

        db.collection("tasks")
            .document(item.id)
            .updateData([
                "isCompleted": !item.isCompleted
            ]) { error in

                if let error = error {
                    print("Completion error: \(error.localizedDescription)")
                }
            }
    }
}

// MARK: - Login and Registration

struct LoginView: View {

    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var errorMessage = ""

    var body: some View {

        NavigationStack {

            VStack(spacing: 20) {

                Image(systemName: "checklist")
                    .font(.system(size: 65))
                    .foregroundColor(.blue)

                Text("My Todo App")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(isRegistering ? "Create your account" : "Welcome back")
                    .foregroundColor(.secondary)

                TextField("Email Address", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                Button {
                    authenticate()
                } label: {

                    Text(isRegistering ? "Register" : "Login")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button {
                    isRegistering.toggle()
                    errorMessage = ""
                } label: {

                    Text(
                        isRegistering
                        ? "Already have an account? Login"
                        : "Don't have an account? Register"
                    )
                }

                if !errorMessage.isEmpty {

                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Spacer()
            }
            .padding(25)
            .navigationTitle("Home")
        }
    }

    // MARK: - Firebase Authentication

    func authenticate() {

        let cleanEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }

        if isRegistering {

            Auth.auth().createUser(
                withEmail: cleanEmail,
                password: password
            ) { _, error in

                if let error = error {
                    errorMessage = error.localizedDescription
                }
            }

        } else {

            Auth.auth().signIn(
                withEmail: cleanEmail,
                password: password
            ) { _, error in

                if let error = error {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Add/Edit Task Screen

struct TodoEditorView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var title: String

    let item: TodoItem?
    let onSave: (String) -> Void

    init(item: TodoItem?, onSave: @escaping (String) -> Void) {

        self.item = item
        self.onSave = onSave

        _title = State(initialValue: item?.title ?? "")
    }

    var body: some View {

        NavigationStack {

            Form {

                Section("Task Details") {

                    TextField("Enter task name", text: $title)
                }

                Section {

                    Button(item == nil ? "Add Task" : "Update Task") {

                        let cleanTitle = title.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                        guard !cleanTitle.isEmpty else { return }

                        onSave(cleanTitle)
                        dismiss()
                    }
                    .disabled(
                        title.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
            .navigationTitle(item == nil ? "New Task" : "Edit Task")
            .toolbar {

                ToolbarItem(placement: .topBarTrailing) {

                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
