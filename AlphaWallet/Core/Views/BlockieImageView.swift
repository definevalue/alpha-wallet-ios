//
//  BlockieImageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.11.2020.
//

import UIKit

class BlockieImageView: UIView {
    private var subscriptionKey: Subscribable<BlockiesImage>.SubscribableKey?

    private var button: UIButton = {
        let imageView = UIButton()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    var subscribable: Subscribable<BlockiesImage>? {
        didSet {
            if let previousSubscribable = oldValue, let subscriptionKey = subscriptionKey {
                previousSubscribable.unsubscribe(subscriptionKey)
            }

            if let subscribable = subscribable {
                subscriptionKey = subscribable.subscribe { [weak self] imageAndSymbol in
                    guard let strongSelf = self else { return }

                    strongSelf.button.setImage(imageAndSymbol, for: .normal)
                }
            } else {
                subscriptionKey = nil
                button.setImage(nil, for: .normal)
            }
        }
    }

    var image: BlockiesImage? {
        get {
            return button.image(for: .normal)
        }
        set {
            button.setImage(newValue, for: .normal)
        }
    }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true

        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)

        NSLayoutConstraint.activate([
            button.anchorsConstraint(to: self),
        ])
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = frame.width / 2.0
    }

    func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        button.addTarget(target, action: action, for: controlEvents)
    }
}


extension BlockieImageView {
    static var defaultBlockieImageView: BlockieImageView {
        let imageView = BlockieImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),
        ])
        return imageView
    }
}
