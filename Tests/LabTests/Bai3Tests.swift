import Foundation
import LabCore
import LabTestSupport
import Testing
#if SOLUTION
import Solutions
#else
import Exercises
#endif

@Suite("Bài 3 · SearchViewModel")
@MainActor
struct Bai3SearchViewModelTests {

    @Test("Response về sai thứ tự: kết quả cũ không được ghi đè kết quả mới")
    func staleResponseIsIgnored() async throws {
        let api = FakeSearchAPI()
        let vm = SearchViewModel(api: api, sleeper: ImmediateSleeper())

        vm.queryChanged("ph")
        let oldTask = vm.searchTask
        try await withTimeout { try await api.calls.pendingCount.wait(atLeast: 1) }

        vm.queryChanged("pho")
        try await withTimeout { try await api.calls.pendingCount.wait(atLeast: 2) }

        // "pho" về trước...
        api.calls.resolve(first: { $0 == "pho" }, with: .success(["Phở bò", "Phở gà"]))
        try await finish(vm.searchTask)
        #expect(vm.results == ["Phở bò", "Phở gà"])

        // ...rồi "ph" (chậm) mới về.
        api.calls.resolve(first: { $0 == "ph" }, with: .success(["Phở cuốn", "Phá lấu"]))
        try await finish(oldTask)

        #expect(vm.results == ["Phở bò", "Phở gà"], "Kết quả của truy vấn cũ đã ghi đè truy vấn mới.")
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("Gõ liên tục: chỉ truy vấn cuối được gửi đi (debounce); huỷ không hiện thành lỗi")
    func debounceCancelsEarlierQueries() async throws {
        let api = FakeSearchAPI()
        let sleeper = ControlledSleeper()
        let vm = SearchViewModel(api: api, sleeper: sleeper, debounce: .milliseconds(300))

        vm.queryChanged("b")
        let first = vm.searchTask
        try await withTimeout { try await sleeper.calls.pendingCount.wait(atLeast: 1) }

        vm.queryChanged("bu")
        // Task của "b" đang chờ debounce, phải bị huỷ và kết thúc ngay.
        try await finish(first)
        #expect(vm.errorMessage == nil, "Huỷ một truy vấn cũ là chuyện bình thường, không được hiện lỗi.")

        try await withTimeout { try await sleeper.calls.pendingCount.wait(atLeast: 1) }
        sleeper.calls.resolveAll(with: .success(()))
        try await withTimeout { try await api.calls.pendingCount.wait(atLeast: 1) }
        api.calls.resolveAll(with: .success(["Bún bò", "Bún chả"]))
        try await finish(vm.searchTask)

        #expect(api.calls.inputs == ["bu"], "Chỉ truy vấn cuối sau debounce được gửi tới server.")
        #expect(vm.results == ["Bún bò", "Bún chả"])
        #expect(sleeper.calls.inputs.allSatisfy { $0 == .milliseconds(300) })
    }

    @Test("Xoá ô tìm kiếm: kết quả về rỗng ngay; response đang bay bị bỏ qua")
    func clearingQueryDropsInFlightSearch() async throws {
        let api = FakeSearchAPI()
        let vm = SearchViewModel(api: api, sleeper: ImmediateSleeper())

        vm.queryChanged("com")
        let inFlight = vm.searchTask
        try await withTimeout { try await api.calls.pendingCount.wait(atLeast: 1) }

        vm.queryChanged("   ")
        #expect(vm.results.isEmpty)
        #expect(vm.isLoading == false)

        api.calls.resolveAll(with: .success(["Cơm tấm"]))
        try await finish(inFlight)

        #expect(vm.results.isEmpty, "Danh sách cũ hiện lại sau khi người dùng đã xoá ô tìm kiếm.")
        #expect(api.calls.inputs == ["com"], "Ô chỉ có khoảng trắng thì không được gọi API.")
    }

    @Test("Khoảng trắng thừa bị cắt; nhập lại đúng truy vấn hiện tại không gửi request mới")
    func trimsAndSkipsDuplicateQueries() async throws {
        let api = FakeSearchAPI { query in ["Kết quả cho \(query)"] }
        let vm = SearchViewModel(api: api, sleeper: ImmediateSleeper())

        vm.queryChanged("  bánh mì ")
        try await finish(vm.searchTask)
        vm.queryChanged("bánh mì")
        try await finish(vm.searchTask)

        #expect(api.calls.inputs == ["bánh mì"])
        #expect(vm.results == ["Kết quả cho bánh mì"])
        #expect(vm.query == "bánh mì")
    }

    @Test("Lỗi mạng hiện thông báo; lần tìm sau thành công thì thông báo biến mất")
    func errorIsShownThenClearedBySuccess() async throws {
        let api = FakeSearchAPI()
        let vm = SearchViewModel(api: api, sleeper: ImmediateSleeper())

        vm.queryChanged("trà sữa")
        #expect(vm.isLoading)
        try await withTimeout { try await api.calls.pendingCount.wait(atLeast: 1) }
        api.calls.resolveAll(with: .failure(URLError(.timedOut)))
        try await finish(vm.searchTask)

        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)

        vm.queryChanged("trà sữa trân châu")
        #expect(vm.isLoading)
        try await withTimeout { try await api.calls.pendingCount.wait(atLeast: 1) }
        api.calls.resolveAll(with: .success(["Trà sữa trân châu đường đen"]))
        try await finish(vm.searchTask)

        #expect(vm.errorMessage == nil, "Lỗi cũ vẫn còn hiện dù lần tìm mới đã thành công.")
        #expect(vm.results == ["Trà sữa trân châu đường đen"])
        #expect(vm.isLoading == false)
    }
}
