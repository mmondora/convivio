import Foundation
import UIKit
import PDFKit

// MARK: - PDF Generator

@MainActor
class PDFGenerator {
    // MARK: - Page Constants

    private static let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
    private static let margin: CGFloat = 50
    private static let contentWidth: CGFloat = 495 // 595 - 2*50

    // MARK: - Fonts

    private static let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
    private static let subtitleFont = UIFont.systemFont(ofSize: 14, weight: .medium)
    private static let headerFont = UIFont.systemFont(ofSize: 18, weight: .bold)
    private static let subheaderFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
    private static let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
    private static let captionFont = UIFont.systemFont(ofSize: 9, weight: .regular)

    // MARK: - Colors

    private static let primaryColor = UIColor(red: 0.5, green: 0.2, blue: 0.6, alpha: 1.0) // Purple
    private static let secondaryColor = UIColor.darkGray
    private static let accentColor = UIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0) // Wine color

    // MARK: - Generate PDF

    static func generateMenuPDF(from dettaglio: DettaglioMenuCompleto, dinner: DinnerEvent) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            var currentY: CGFloat = margin

            // MARK: - Title Page
            context.beginPage()
            currentY = margin

            // Title
            currentY = drawCenteredText(
                dettaglio.dinnerTitle,
                font: titleFont,
                color: primaryColor,
                y: currentY + 40,
                context: context
            )

            // Date and guests
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .full
            dateFormatter.locale = Locale(identifier: "it_IT")

            currentY = drawCenteredText(
                dateFormatter.string(from: dettaglio.dinnerDate),
                font: subtitleFont,
                color: secondaryColor,
                y: currentY + 20,
                context: context
            )

            currentY = drawCenteredText(
                "\(dettaglio.guestCount) persone",
                font: subtitleFont,
                color: secondaryColor,
                y: currentY + 10,
                context: context
            )

            // Decorative line
            currentY += 30
            drawLine(y: currentY, context: context)
            currentY += 30

            // Table of contents
            currentY = drawText(
                "INDICE",
                font: headerFont,
                color: primaryColor,
                x: margin,
                y: currentY,
                width: contentWidth,
                context: context
            )
            currentY += 20

            let tocItems = [
                "1. Ricette Dettagliate",
                "2. Timeline di Preparazione",
                "3. Servizio Vini",
                "4. Lista della Spesa",
                "5. Mise en Place",
                "6. Consigli di Galateo"
            ]

            for item in tocItems {
                currentY = drawText(
                    item,
                    font: bodyFont,
                    color: secondaryColor,
                    x: margin + 20,
                    y: currentY,
                    width: contentWidth - 20,
                    context: context
                )
                currentY += 5
            }

            // MARK: - Recipes Section
            context.beginPage()
            currentY = margin

            currentY = drawSectionHeader("RICETTE DETTAGLIATE", y: currentY, context: context)

            for portata in dettaglio.portate {
                // Check if we need a new page
                if currentY > pageRect.height - 200 {
                    context.beginPage()
                    currentY = margin
                }

                // Course name
                currentY = drawText(
                    portata.courseName.uppercased(),
                    font: captionFont,
                    color: primaryColor,
                    x: margin,
                    y: currentY,
                    width: contentWidth,
                    context: context
                )

                // Dish name
                currentY = drawText(
                    portata.dishName,
                    font: subheaderFont,
                    color: .black,
                    x: margin,
                    y: currentY + 5,
                    width: contentWidth,
                    context: context
                )

                currentY += 10

                // Ingredients
                currentY = drawText(
                    "Ingredienti (\(portata.recipe.servings) persone):",
                    font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    color: secondaryColor,
                    x: margin,
                    y: currentY,
                    width: contentWidth,
                    context: context
                )

                for ingredient in portata.recipe.ingredients {
                    if currentY > pageRect.height - 50 {
                        context.beginPage()
                        currentY = margin
                    }

                    currentY = drawText(
                        "• \(ingredient.displayText)",
                        font: captionFont,
                        color: secondaryColor,
                        x: margin + 10,
                        y: currentY + 3,
                        width: contentWidth - 10,
                        context: context
                    )
                }

                currentY += 10

                // Procedure
                currentY = drawText(
                    "Procedimento:",
                    font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    color: secondaryColor,
                    x: margin,
                    y: currentY,
                    width: contentWidth,
                    context: context
                )

                for (index, step) in portata.recipe.procedure.enumerated() {
                    if currentY > pageRect.height - 50 {
                        context.beginPage()
                        currentY = margin
                    }

                    currentY = drawText(
                        "\(index + 1). \(step)",
                        font: captionFont,
                        color: secondaryColor,
                        x: margin + 10,
                        y: currentY + 3,
                        width: contentWidth - 10,
                        context: context
                    )
                }

                currentY += 20
            }

            // MARK: - Timeline Section
            context.beginPage()
            currentY = margin

            currentY = drawSectionHeader("TIMELINE DI PREPARAZIONE", y: currentY, context: context)

            for step in dettaglio.timeline.sorted(by: { $0.timeOffset < $1.timeOffset }) {
                if currentY > pageRect.height - 60 {
                    context.beginPage()
                    currentY = margin
                }

                // Time
                currentY = drawText(
                    step.formattedTime,
                    font: UIFont.systemFont(ofSize: 10, weight: .bold),
                    color: primaryColor,
                    x: margin,
                    y: currentY,
                    width: 100,
                    context: context
                )

                // Description
                currentY = drawText(
                    step.description,
                    font: bodyFont,
                    color: .black,
                    x: margin + 110,
                    y: currentY - 12, // Align with time
                    width: contentWidth - 110,
                    context: context
                )

                if let dish = step.relatedDish {
                    currentY = drawText(
                        "→ \(dish)",
                        font: captionFont,
                        color: secondaryColor,
                        x: margin + 110,
                        y: currentY,
                        width: contentWidth - 110,
                        context: context
                    )
                }

                currentY += 15
            }

            // MARK: - Wine Service Section
            if !dettaglio.wineService.isEmpty {
                context.beginPage()
                currentY = margin

                currentY = drawSectionHeader("SERVIZIO VINI", y: currentY, context: context)

                for wine in dettaglio.wineService.sorted(by: { $0.servingOrder < $1.servingOrder }) {
                    if currentY > pageRect.height - 80 {
                        context.beginPage()
                        currentY = margin
                    }

                    // Wine name with number
                    currentY = drawText(
                        "\(wine.servingOrder). \(wine.wineName)",
                        font: subheaderFont,
                        color: accentColor,
                        x: margin,
                        y: currentY,
                        width: contentWidth,
                        context: context
                    )

                    // Details
                    let details = [
                        "Temperatura: \(wine.formattedTemp)",
                        "Bicchiere: \(wine.glassType)",
                        wine.decantTime.map { "Decantazione: \($0)" },
                        "Abbinamento: \(wine.pairedWith)"
                    ].compactMap { $0 }

                    for detail in details {
                        currentY = drawText(
                            detail,
                            font: captionFont,
                            color: secondaryColor,
                            x: margin + 20,
                            y: currentY + 3,
                            width: contentWidth - 20,
                            context: context
                        )
                    }

                    currentY += 15
                }
            }

            // MARK: - Shopping List Section
            context.beginPage()
            currentY = margin

            currentY = drawSectionHeader("LISTA DELLA SPESA", y: currentY, context: context)

            for category in dettaglio.shoppingList {
                if currentY > pageRect.height - 100 {
                    context.beginPage()
                    currentY = margin
                }

                // Category name
                currentY = drawText(
                    category.category.uppercased(),
                    font: UIFont.systemFont(ofSize: 10, weight: .bold),
                    color: primaryColor,
                    x: margin,
                    y: currentY,
                    width: contentWidth,
                    context: context
                )
                currentY += 5

                for item in category.items {
                    if currentY > pageRect.height - 30 {
                        context.beginPage()
                        currentY = margin
                    }

                    currentY = drawText(
                        "☐ \(item.quantity) \(item.name)",
                        font: bodyFont,
                        color: .black,
                        x: margin + 10,
                        y: currentY,
                        width: contentWidth - 10,
                        context: context
                    )
                    currentY += 3
                }

                currentY += 10
            }

            // MARK: - Mise en Place Section
            context.beginPage()
            currentY = margin

            currentY = drawSectionHeader("MISE EN PLACE", y: currentY, context: context)

            // Table Settings
            if !dettaglio.miseEnPlace.tableSettings.isEmpty {
                currentY = drawText(
                    "Disposizione Tavola:",
                    font: subheaderFont,
                    color: primaryColor,
                    x: margin,
                    y: currentY,
                    width: contentWidth,
                    context: context
                )

                for setting in dettaglio.miseEnPlace.tableSettings {
                    currentY = drawText(
                        "• \(setting)",
                        font: bodyFont,
                        color: secondaryColor,
                        x: margin + 10,
                        y: currentY + 5,
                        width: contentWidth - 10,
                        context: context
                    )
                }
                currentY += 15
            }

            // Serving Order
            if !dettaglio.miseEnPlace.servingOrder.isEmpty {
                currentY = drawText(
                    "Ordine di Servizio:",
                    font: subheaderFont,
                    color: primaryColor,
                    x: margin,
                    y: currentY,
                    width: contentWidth,
                    context: context
                )

                for (index, order) in dettaglio.miseEnPlace.servingOrder.enumerated() {
                    currentY = drawText(
                        "\(index + 1). \(order)",
                        font: bodyFont,
                        color: secondaryColor,
                        x: margin + 10,
                        y: currentY + 5,
                        width: contentWidth - 10,
                        context: context
                    )
                }
                currentY += 15
            }

            // MARK: - Etiquette Section
            if !dettaglio.etiquette.isEmpty {
                if currentY > pageRect.height - 150 {
                    context.beginPage()
                    currentY = margin
                }

                currentY = drawSectionHeader("CONSIGLI DI GALATEO", y: currentY, context: context)

                for tip in dettaglio.etiquette {
                    if currentY > pageRect.height - 50 {
                        context.beginPage()
                        currentY = margin
                    }

                    currentY = drawText(
                        "✦ \(tip)",
                        font: bodyFont,
                        color: secondaryColor,
                        x: margin,
                        y: currentY,
                        width: contentWidth,
                        context: context
                    )
                    currentY += 10
                }
            }

            // MARK: - Footer
            context.beginPage()
            currentY = pageRect.height - 100

            drawLine(y: currentY, context: context)

            currentY = drawCenteredText(
                "Menu generato con Convivio",
                font: captionFont,
                color: secondaryColor,
                y: currentY + 20,
                context: context
            )
        }
    }

    // MARK: - Drawing Helpers

    private static func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let rect = CGRect(x: x, y: y, width: width, height: .greatestFiniteMagnitude)
        let boundingRect = attributedString.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)

        attributedString.draw(in: CGRect(x: x, y: y, width: width, height: boundingRect.height))

        return y + boundingRect.height
    }

    private static func drawCenteredText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        y: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        let rect = CGRect(x: margin, y: y, width: contentWidth, height: boundingRect.height)
        attributedString.draw(in: rect)

        return y + boundingRect.height
    }

    private static func drawSectionHeader(
        _ text: String,
        y: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var currentY = y

        // Draw header text
        currentY = drawText(
            text,
            font: headerFont,
            color: primaryColor,
            x: margin,
            y: currentY,
            width: contentWidth,
            context: context
        )

        // Draw underline
        currentY += 5
        drawLine(y: currentY, context: context)

        return currentY + 20
    }

    private static func drawLine(y: CGFloat, context: UIGraphicsPDFRendererContext) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
        primaryColor.withAlphaComponent(0.3).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}
