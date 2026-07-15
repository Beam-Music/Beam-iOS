//
//  KeyboardAvoidingScrollView.swift
//  BeamApp
//
//  Created by anonymous on 6/10/25.
//


import SwiftUI

struct KeyboardAvoidingScrollView<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true

        // SwiftUI Content를 HostingController로 감싸서 UIScrollView에 Add
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        scrollView.addSubview(hostingController.view)

        // 오토레이아웃
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // 키보드 노티피케이션 등Rock
        context.coordinator.scrollView = scrollView
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.keyboardWillShow(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.keyboardWillHide(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // SwiftUI Content 업데이트
        if let hostingController = uiView.subviews.compactMap({ $0.next as? UIHostingController<Content> }).first {
            hostingController.rootView = content
        }
    }

    class Coordinator: NSObject {
        weak var scrollView: UIScrollView?

        @objc func keyboardWillShow(notification: Notification) {
            guard let scrollView = scrollView,
                  let userInfo = notification.userInfo,
                  let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let window = scrollView.window else { return }

            let keyboardHeight = window.convert(keyboardFrame, from: nil).height
            let bottomInset = keyboardHeight - window.safeAreaInsets.bottom

            var contentInset = scrollView.contentInset
            contentInset.bottom = bottomInset
            scrollView.contentInset = contentInset
            scrollView.scrollIndicatorInsets = contentInset

            // 현재 firstResponder가 키보드에 가려지면 자동 스크롤 (하단 여유 20 Add)
            if let firstResponder = findFirstResponder(in: scrollView) {
                let responderFrame = firstResponder.convert(firstResponder.bounds, to: scrollView)
                var visibleRect = scrollView.bounds
                visibleRect.size.height -= bottomInset
                visibleRect.origin.y = scrollView.contentOffset.y
                if !visibleRect.contains(responderFrame) {
                    // firstResponder의 하단이 키보드 위에 오도Rock 오프셋 조정
                    let targetY = responderFrame.maxY - visibleRect.height + 20
                    let offset = max(targetY, 0)
                    scrollView.setContentOffset(CGPoint(x: 0, y: offset), animated: true)
                }
            }
        }

        @objc func keyboardWillHide(notification: Notification) {
            guard let scrollView = scrollView else { return }
            var contentInset = scrollView.contentInset
            contentInset.bottom = 0
            scrollView.contentInset = contentInset
            scrollView.scrollIndicatorInsets = contentInset
        }

        private func findFirstResponder(in view: UIView) -> UIView? {
            if view.isFirstResponder { return view }
            for subview in view.subviews {
                if let responder = findFirstResponder(in: subview) {
                    return responder
                }
            }
            return nil
        }
    }
}
