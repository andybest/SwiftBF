/*
 
 MIT License
 
 Copyright (c) 2017 Andy Best
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 
 */

import Foundation

enum BfAstNode {
    case add(UInt8)
    case subtract(UInt8)
    case incDataPointer(UInt8)
    case decDataPointer(UInt8)
    case loop([BfAstNode])
    case outputChar
    case getChar
}

class BFReader {
    var source: String
    var sourceIndex: String.Index
    
    init(source: String) {
        self.source = source
        sourceIndex = self.source.startIndex
    }
    
    func genAst() -> [BfAstNode] {
        var ast = [BfAstNode]()
        
        while(sourceIndex < source.endIndex) {
            switch(source[sourceIndex]) {
            case "+":
                var addVal: UInt8 = 1
                
                while(source[source.index(after: sourceIndex)] == "+") {
                    sourceIndex = source.index(after: sourceIndex)
                    addVal += 1
                    
                    if addVal == 255 {
                        ast.append(.add(255))
                        addVal = 0
                    }
                    
                    if source.index(after: sourceIndex) == source.endIndex {
                        break
                    }
                }
                
                ast.append(.add(addVal))
                
            case "-":
                var subVal: UInt8 = 1
                
                while(source[source.index(after: sourceIndex)] == "-") {
                    sourceIndex = source.index(after: sourceIndex)
                    subVal += 1
                    
                    if subVal == 255 {
                        ast.append(.subtract(255))
                        subVal = 0
                    }
                }
                
                ast.append(.subtract(subVal))
            case ">":
                var addVal: UInt8 = 1
                
                while(source[source.index(after: sourceIndex)] == ">") {
                    sourceIndex = source.index(after: sourceIndex)
                    addVal += 1
                    
                    if addVal == 255 {
                        ast.append(.incDataPointer(255))
                        addVal = 0
                    }
                }
                
                ast.append(.incDataPointer(addVal))
            case "<":
                var subVal: UInt8 = 1
                
                while(source[source.index(after: sourceIndex)] == "<") {
                    sourceIndex = source.index(after: sourceIndex)
                    subVal += 1
                    
                    if subVal == 255 {
                        ast.append(.decDataPointer(255))
                        subVal = 0
                    }
                }
                
                ast.append(.decDataPointer(subVal))
            case "[":
                ast.append(extractLoop())
            case ".":
                ast.append(.outputChar)
            case ",":
                ast.append(.getChar)
            default:
                break
            }
            
            sourceIndex = source.index(after: sourceIndex)
        }
        
        return ast
    }
        
    func extractLoop() -> BfAstNode {
        var brackets = 1
        
        var loopContents = ""
        
        while brackets > 0 {
            sourceIndex = source.index(after: sourceIndex)
            
            let c = source[sourceIndex]
            
            if c == "[" {
                brackets += 1
            } else if c == "]" {
                brackets -= 1
            }
            
            loopContents.append(c)
        }
        
        let loopReader = BFReader(source: loopContents)
        return .loop(loopReader.genAst())
    }
            
}

class SwiftBFTranspiler {
    
    var output: String = ""
    let currentMemoryStatement = "memory[Int(dataPointer)]"
    var indentLevel: Int = 1
    
    
    init(source: String) {
        // Clean the source of all non-opcode characters
        var cleanedSource = ""
        
        let opcodeSet = CharacterSet(charactersIn: "+-<>,.[]")
        for s in source.unicodeScalars {
            if opcodeSet.contains(s) {
                cleanedSource.append(Character(s))
            }
        }
        
        let reader = BFReader(source: cleanedSource)
        emitSource(reader.genAst())
        print(output)
    }
    
    func emitSource(_ nodes: [BfAstNode]) {
        output += "func bfMain() {\n"
        addIndent()
        output += "var memory: [UInt8] = [UInt8](repeating: 0, count: 0xFFFF)\n"
        addIndent()
        output += "var dataPointer: UInt16 = 0\n"
        addIndent()
        output += "let buf = UnsafeMutablePointer<CChar>.allocate(capacity: 1)\n\n"
        
        for node in nodes {
            emit(node: node)
        }
        
        output += "}\n "
        output += "bfMain()\n"
    }
    
    func addIndent() {
        for _ in 0..<indentLevel {
            output += "\t"
        }
    }
    
    func emit(node: BfAstNode) {
        switch node {
        case .add(let val):
            addIndent()
            output += "memory[Int(dataPointer)] = memory[Int(dataPointer)].addingReportingOverflow(\(val)).partialValue\n"
        case .subtract(let val):
            addIndent()
            output += "memory[Int(dataPointer)] = memory[Int(dataPointer)].subtractingReportingOverflow(\(val)).partialValue\n"
        case .incDataPointer(let val):
            addIndent()
            output += "dataPointer = dataPointer.addingReportingOverflow(\(val)).partialValue\n"
        case .decDataPointer(let val):
            addIndent()
            output += "dataPointer = dataPointer.subtractingReportingOverflow(\(val)).partialValue\n"
        case .loop(let nodes):
            addIndent()
            output += "while memory[Int(dataPointer)] > 0 {\n"
            indentLevel += 1
            for node in nodes {
                emit(node: node)
            }
            indentLevel -= 1
            addIndent()
            output += "}\n"
        case .outputChar:
            addIndent()
            output += "print(UnicodeScalar(memory[Int(dataPointer)]), terminator: \"\")\n"
        case .getChar:
            addIndent()
            output += "fread(buf, 1, 1, stdin)\n"
            addIndent()
            output += "memory[Int(dataPointer)] = UInt8(buf.pointee)\n"
        }
    }
    
}
