
//
//  ReportGenerator.swift
//  Quality Control
//
//  Created by Melike SEYİTOĞLU on 9.12.2024.
//

import Foundation
import libxlsxwriter

class ReportGenerator {
    private var object: VirtualObject
    private(set) var filePath: String

    init(for virtualObject: VirtualObject, reportsDirectory: String) {
        self.object = virtualObject
        let fileName = "\(virtualObject.name)_\(UUID().uuidString).xlsx"
        self.filePath = (reportsDirectory as NSString).appendingPathComponent(fileName)
    }

    /// Creates a new Excel report file.
    func createReport() throws {
        guard let workbook = workbook_new(filePath) else {
            throw NSError(domain: "ReportGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create workbook"])
        }
        
        guard let worksheet = workbook_add_worksheet(workbook, nil) else {
            workbook_close(workbook)
            throw NSError(domain: "ReportGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create worksheet"])
        }

        // Write object info
        writeString("Object Name", to: worksheet, row: 0, col: 0)
        writeString(object.name, to: worksheet, row: 0, col: 1)

        writeString("Width", to: worksheet, row: 1, col: 0)
        writeNumber(object.width, to: worksheet, row: 1, col: 1)

        writeString("Height", to: worksheet, row: 2, col: 0)
        writeNumber(object.height, to: worksheet, row: 2, col: 1)

        writeString("Depth", to: worksheet, row: 3, col: 0)
        writeNumber(object.depth, to: worksheet, row: 3, col: 1)

        // Blank line
        writeString("Inspection Points", to: worksheet, row: 5, col: 0)
        writeString("Name", to: worksheet, row: 6, col: 0)
        writeString("Count", to: worksheet, row: 6, col: 1)
        writeString("Description", to: worksheet, row: 6, col: 2)
        writeString("Correct", to: worksheet, row: 6, col: 3)

        var currentRow: lxw_row_t = 7
        for point in object.inspectionPoints {
            writeString(point.name, to: worksheet, row: currentRow, col: 0)

            // Count
            if point.hasCount, let countVal = point.count {
                writeNumber(Double(countVal), to: worksheet, row: currentRow, col: 1)
            } else {
                writeString("-", to: worksheet, row: currentRow, col: 1)
            }

            // Description
            if point.hasDescription, let descVal = point.description {
                writeString(descVal, to: worksheet, row: currentRow, col: 2)
            } else {
                writeString("-", to: worksheet, row: currentRow, col: 2)
            }

            // Is Correct
            if point.hasIsCorrect, let correctVal = point.isCorrect {
                writeString(correctVal ? "Yes" : "No", to: worksheet, row: currentRow, col: 3)
            } else {
                writeString("-", to: worksheet, row: currentRow, col: 3)
            }

            currentRow += 1
        }

        workbook_close(workbook)
    }

    /// Updates the existing report by regenerating it with appended inspection points.
    func updateReport(with newInspections: [InspectionPoint]) throws {
        let updatedObject = VirtualObject(
            name: object.name,
            width: object.width,
            height: object.height,
            depth: object.depth,
            inspectionPoints: object.inspectionPoints + newInspections
        )

        self.object = updatedObject
        try createReport()
    }

    // MARK: - Helper Writing Functions

    private func writeString(_ string: String, to worksheet: UnsafeMutablePointer<lxw_worksheet>, row: lxw_row_t, col: lxw_col_t) {
        worksheet_write_string(worksheet, row, col, string, nil)
    }

    private func writeNumber(_ number: Double, to worksheet: UnsafeMutablePointer<lxw_worksheet>, row: lxw_row_t, col: lxw_col_t) {
        worksheet_write_number(worksheet, row, col, number, nil)
    }
}
