import SwiftUI
import UIKit

/// Form-safe title field that grows with every line. No clipping, no inner scroll.
struct GrowingNameField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        AutosizingTextView(text: $text, placeholder: placeholder)
            .frame(minHeight: 22)
            .padding(.vertical, 4)
    }
}

private struct AutosizingTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> IntrinsicHeightTextView {
        let view = IntrinsicHeightTextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = UIColor.label
        view.tintColor = UIColor.label
        view.isScrollEnabled = false
        view.keyboardDismissMode = .interactive
        view.textContainer.lineFragmentPadding = 0
        view.textContainerInset = .zero
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.placeholderLabel.text = placeholder
        context.coordinator.attach(to: view)
        context.coordinator.apply(text, to: view)
        return view
    }

    func updateUIView(_ uiView: IntrinsicHeightTextView, context: Context) {
        context.coordinator.parentText = $text
        uiView.placeholderLabel.text = placeholder
        if uiView.text != text {
            context.coordinator.apply(text, to: uiView)
        } else {
            uiView.refreshPlaceholder()
            uiView.invalidateIntrinsicContentSize()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parentText: Binding<String>
        private weak var textView: IntrinsicHeightTextView?

        init(text: Binding<String>) {
            parentText = text
        }

        func attach(to view: IntrinsicHeightTextView) {
            textView = view
        }

        func apply(_ value: String, to view: IntrinsicHeightTextView) {
            view.text = value
            view.refreshPlaceholder()
            view.invalidateIntrinsicContentSize()
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let view = textView as? IntrinsicHeightTextView else { return }
            parentText.wrappedValue = view.text
            view.refreshPlaceholder()
            view.invalidateIntrinsicContentSize()
            // Nudge SwiftUI to re-measure the form row on the next turn.
            DispatchQueue.main.async {
                view.invalidateIntrinsicContentSize()
            }
        }
    }
}

private final class IntrinsicHeightTextView: UITextView {
    let placeholderLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = UIColor.placeholderText
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refreshPlaceholder() {
        placeholderLabel.isHidden = !text.isEmpty
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 1
            ? bounds.width
            : (superview?.bounds.width ?? UIScreen.main.bounds.width - 64)
        let fitted = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: max(22, ceil(fitted.height)))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}
