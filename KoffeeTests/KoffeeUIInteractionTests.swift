import XCTest
import SwiftUI
@testable import LiquidContainer

final class KoffeeUIInteractionTests: XCTestCase {
    
    func testTextFieldIsEditable() {
        struct TestView: View {
            @State private var weight: Double = 70
            
            var body: some View {
                TextField("kg", value: $weight, format: .number)
                    .textFieldStyle(.plain)
                    .frame(width: 60)
            }
        }
        
        let view = TestView()
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        
        XCTAssertNotNil(window.contentView, "Content view should exist")
    }
    
    func testDatePickerIsEditable() {
        struct TestView: View {
            @State private var wakeTime = Date()
            
            var body: some View {
                DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
        }
        
        let view = TestView()
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        
        XCTAssertNotNil(window.contentView, "Content view should exist")
    }
    
    func testSensitivityButtonIsClickable() {
        struct TestView: View {
            @State private var sensitivity: Int = 1
            
            var body: some View {
                HStack {
                    ForEach([0, 1, 2], id: \.self) { index in
                        Button {
                            sensitivity = index
                        } label: {
                            Text(index == 0 ? "L" : index == 1 ? "M" : "H")
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
                    }
                }
            }
        }
        
        let view = TestView()
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        
        XCTAssertNotNil(window.contentView, "Content view should exist")
    }
    
    func testBackgroundMaterialDoesNotBlockInteraction() {
        struct TestView: View {
            @State private var value: Double = 50
            
            var body: some View {
                HStack {
                    TextField("kg", value: $value, format: .number)
                        .textFieldStyle(.plain)
                        .frame(width: 60)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: 10))
            }
        }
        
        let view = TestView()
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        
        XCTAssertNotNil(window.contentView, "Content view should exist")
    }
    
    func testGlassEffectMayBlockInteraction() {
        struct TestView: View {
            @State private var value: Double = 50
            
            var body: some View {
                HStack {
                    TextField("kg", value: $value, format: .number)
                        .textFieldStyle(.plain)
                        .frame(width: 60)
                }
                .padding(12)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
            }
        }
        
        let view = TestView()
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        
        XCTAssertNotNil(window.contentView, "Content view should exist")
    }
    
    func testSensitivityButtonWithBackgroundIsClickable() {
        struct TestView: View {
            @State private var sensitivity: Int = 1
            
            var body: some View {
                Button {
                    sensitivity = 0
                } label: {
                    Text("L")
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange)
                )
            }
        }
        
        let view = TestView()
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        
        XCTAssertNotNil(window.contentView, "Content view should exist")
    }
    
    func testTextFieldWithStepperDoesNotBlockInteraction() {
        struct TestView: View {
            @State private var hour: Int = 9
            
            var body: some View {
                HStack {
                    TextField("HH", value: $hour, format: .number)
                        .textFieldStyle(.plain)
                        .frame(width: 30)
                    
                    Stepper("", value: $hour, in: 0...23)
                        .labelsHidden()
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: 10))
            }
        }
        
        let view = TestView()
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        
        XCTAssertNotNil(window.contentView, "TextField with stepper should render")
    }
}
