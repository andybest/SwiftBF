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

class SwiftBFInterpreter {
    var memory = [UInt8](repeating: 0, count: 30000)
    var dataPointer: UInt = 0
    var instructionPointer: String.Index
    var input: String = ""
    
    init(source: String) {
        self.input = source
        instructionPointer = input.startIndex
    }
    
    func run() {
        while instructionPointer < input.endIndex {
            runOpcode(input[instructionPointer])
        }
    }
    
    func runOpcode(_ opcode: Character) {
        switch opcode {
        case ">":
            dataPointer += 1
            if dataPointer >= memory.count {
                dataPointer = 0
            }
            instructionPointer = input.index(after: instructionPointer)
            
        case "<":
            if dataPointer == 0 {
                dataPointer = UInt(memory.count - 1)
            } else {
                dataPointer -= 1
            }
            instructionPointer = input.index(after: instructionPointer)
            
        case "+":
            memory[Int(dataPointer)] = memory[Int(dataPointer)].addingReportingOverflow(1).partialValue
            instructionPointer = input.index(after: instructionPointer)
            
        case "-":
            memory[Int(dataPointer)] = memory[Int(dataPointer)].subtractingReportingOverflow(1).partialValue
            instructionPointer = input.index(after: instructionPointer)
            
        case ".":
            print(UnicodeScalar(memory[Int(dataPointer)]), terminator: "")
            instructionPointer = input.index(after: instructionPointer)
            
        case ",":
            let buf = UnsafeMutablePointer<CChar>.allocate(capacity: 1)
            fread(buf, 1, 1, stdin)
            memory[Int(dataPointer)] = UInt8(buf.pointee)
            instructionPointer = input.index(after: instructionPointer)
            
        case "[":
            if memory[Int(dataPointer)] == 0x0 {
                var bracketStack = 1
                while bracketStack > 0 {
                    instructionPointer = input.index(after: instructionPointer)
                    
                    let currentOpcode = input[instructionPointer]
                    if currentOpcode == "[" {
                        bracketStack += 1
                    } else if currentOpcode == "]" {
                        bracketStack -= 1
                    }
                }
                instructionPointer = input.index(after: instructionPointer)
            } else {
                instructionPointer = input.index(after: instructionPointer)
            }
            
        case "]":
            if memory[Int(dataPointer)] > 0x0 {
                var bracketStack = 1
                while bracketStack > 0 {
                    instructionPointer = input.index(before: instructionPointer)
                    let currentOpcode = input[instructionPointer]
                    if currentOpcode == "]" {
                        bracketStack += 1
                    } else if currentOpcode == "[" {
                        bracketStack -= 1
                    }
                }
                instructionPointer = input.index(after: instructionPointer)
            } else {
                instructionPointer = input.index(after: instructionPointer)
            }
            
        default:
            instructionPointer = input.index(after: instructionPointer)
        }
    }
}
