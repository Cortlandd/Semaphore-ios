import SwiftUI

struct MarkdownDocumentView: View {
    let document: MarkdownDocument

    var body: some View {
        GridBackground {
            ScrollView {
                VStack(spacing: 0) {
                    VStack {
                        Spacer()

                        Text(document.title)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(SemaphorePalette.accent)

                        Spacer(minLength: 34)
                    }
                    .padding(24)
                    .frame(height: 220)

                    VStack(alignment: .leading, spacing: 12) {
                        if let attributed = markdownAttributedString(document: document) {
                            Text(attributed)
                                .foregroundStyle(SemaphorePalette.accent)
                        } else {
                            Text(markdownString(document: document))
                                .foregroundStyle(SemaphorePalette.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.top, -24)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func markdownString(document: MarkdownDocument) -> String {
        guard let url = Bundle.main.url(forResource: document.rawValue, withExtension: "md"),
              let value = try? String(contentsOf: url)
        else {
            return "# Missing Resource\nUnable to load \(document.title)."
        }

        return value
    }

    private func markdownAttributedString(document: MarkdownDocument) -> AttributedString? {
        try? AttributedString(markdown: markdownString(document: document))
    }
}
