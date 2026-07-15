# ĐẶC TẢ THIẾT KẾ FIFO ĐỒNG BỘ

## 1. Thông tin tài liệu

| Thuộc tính | Giá trị |
|---|---|
| Tên khối | Synchronous FIFO |
| Tên module đề xuất | `sync_fifo` |
| Phiên bản đặc tả | 1.0 |
| Loại mạch | Sequential logic + memory datapath |
| Miền clock | Một miền clock duy nhất |
| Mục đích | Lưu trữ tạm thời và truyền dữ liệu theo thứ tự FIFO |

## 2. Mục tiêu thiết kế

Khối FIFO đồng bộ nhận dữ liệu ở cổng ghi và trả dữ liệu ở cổng đọc theo nguyên tắc **First In, First Out**: dữ liệu được ghi trước phải được đọc trước.

Thiết kế phải:

- Chỉ sử dụng một clock chung cho cả đọc và ghi.
- Cho phép cấu hình độ rộng dữ liệu và số phần tử lưu trữ.
- Phát hiện chính xác trạng thái `full` và `empty`.
- Không làm thay đổi dữ liệu hoặc con trỏ khi có yêu cầu không hợp lệ.
- Hỗ trợ đọc và ghi đồng thời để đạt thông lượng tối đa một phần tử mỗi chu kỳ.
- Có hành vi xác định rõ tại các biên `full`, `empty` và khi đọc–ghi cùng lúc.

## 3. Phạm vi thiết kế

### 3.1. Có trong phiên bản này

- FIFO một clock.
- Ghi, đọc và đọc–ghi đồng thời.
- Cờ `full`, `empty`.
- Bộ đếm số phần tử `data_count`.
- Tín hiệu xác nhận dữ liệu đọc `rd_valid`.
- Tín hiệu báo yêu cầu ghi/đọc bị từ chối: `overflow`, `underflow`.
- Hỗ trợ `DEPTH` không nhất thiết là lũy thừa của 2.

### 3.2. Không thuộc phạm vi phiên bản này

- Asynchronous FIFO hoặc Clock Domain Crossing.
- First-Word Fall-Through/Show-Ahead FIFO.
- `almost_full`, `almost_empty` hoặc ngưỡng lập trình được.
- ECC/parity.
- Nhiều cổng đọc hoặc nhiều cổng ghi.
- Flush riêng ngoài reset.

## 4. Tham số cấu hình

| Parameter | Giá trị mặc định | Ràng buộc | Ý nghĩa |
|---|---:|---|---|
| `DATA_WIDTH` | 8 | `DATA_WIDTH >= 1` | Số bit của mỗi phần tử dữ liệu |
| `DEPTH` | 16 | `DEPTH >= 2` | Số phần tử tối đa FIFO có thể lưu |
| `PTR_WIDTH` | `$clog2(DEPTH)` | Local parameter | Độ rộng con trỏ đọc/ghi |
| `COUNT_WIDTH` | `$clog2(DEPTH+1)` | Local parameter | Độ rộng bộ đếm từ 0 đến `DEPTH` |

Nếu `DEPTH` không phải lũy thừa của 2, con trỏ phải quay về 0 khi đạt `DEPTH-1`; không được dựa hoàn toàn vào hiện tượng tràn tự nhiên của vector nhị phân.

## 5. Giao tiếp tín hiệu

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---:|---|
| `clk` | Input | 1 | Clock chung; trạng thái cập nhật tại cạnh lên |
| `rst_n` | Input | 1 | Reset đồng bộ, active-low |
| `wr_en` | Input | 1 | Yêu cầu ghi một phần tử |
| `wr_data` | Input | `DATA_WIDTH` | Dữ liệu cần ghi |
| `rd_en` | Input | 1 | Yêu cầu đọc một phần tử |
| `rd_data` | Output | `DATA_WIDTH` | Dữ liệu đọc đã đăng ký |
| `rd_valid` | Output | 1 | Bằng 1 trong chu kỳ `rd_data` chứa dữ liệu đọc hợp lệ mới |
| `full` | Output | 1 | FIFO đang chứa đủ `DEPTH` phần tử |
| `empty` | Output | 1 | FIFO không chứa phần tử nào |
| `data_count` | Output | `COUNT_WIDTH` | Số phần tử hiện có trong FIFO |
| `overflow` | Output | 1 | Xung một chu kỳ khi yêu cầu ghi bị từ chối |
| `underflow` | Output | 1 | Xung một chu kỳ khi yêu cầu đọc bị từ chối |

Tất cả input điều khiển và dữ liệu phải ổn định theo yêu cầu setup/hold quanh cạnh lên của `clk`.

## 6. Định nghĩa giao dịch được chấp nhận

Một yêu cầu đọc được chấp nhận khi FIFO không rỗng:

```text
rd_accept = rd_en && !empty
```

Một yêu cầu ghi được chấp nhận khi FIFO chưa đầy, hoặc khi FIFO đầy nhưng đồng thời có một phép đọc hợp lệ giải phóng vị trí:

```text
wr_accept = wr_en && (!full || rd_accept)
```

Quy tắc cập nhật số phần tử:

```text
next_data_count = data_count + wr_accept - rd_accept
```

## 7. Yêu cầu chức năng

### 7.1. Reset

Reset là reset **đồng bộ active-low**.

Tại cạnh lên của `clk`, nếu `rst_n == 0`:

- `read_pointer` được đặt về 0.
- `write_pointer` được đặt về 0.
- `data_count` được đặt về 0.
- `empty` phải bằng 1.
- `full` phải bằng 0.
- `rd_data` được đặt về 0.
- `rd_valid` được đặt về 0.
- `overflow` được đặt về 0.
- `underflow` được đặt về 0.
- Mọi yêu cầu đọc/ghi trong chu kỳ reset đều bị bỏ qua.

Không yêu cầu reset toàn bộ mảng nhớ vì dữ liệu trong memory không hợp lệ khi `data_count == 0`.

### 7.2. Ghi dữ liệu

Khi `wr_accept == 1` tại cạnh lên:

1. `wr_data` được lưu vào vị trí do `write_pointer` chỉ tới.
2. `write_pointer` tăng một vị trí.
3. Nếu `write_pointer == DEPTH-1`, giá trị kế tiếp của nó phải là 0.

Nếu `wr_en == 1` nhưng `wr_accept == 0`:

- Không ghi memory.
- Không thay đổi `write_pointer`.
- `overflow` phải bằng 1 trong chu kỳ sau cạnh lấy mẫu yêu cầu.

### 7.3. Đọc dữ liệu

Khi `rd_accept == 1` tại cạnh lên:

1. Phần tử tại vị trí `read_pointer` được đưa vào `rd_data`.
2. `rd_valid` bằng 1 trong chu kỳ ngay sau cạnh lên đó.
3. `read_pointer` tăng một vị trí.
4. Nếu `read_pointer == DEPTH-1`, giá trị kế tiếp của nó phải là 0.

Đây là giao tiếp đọc có đăng ký. Nếu yêu cầu đọc được lấy mẫu tại cạnh lên N, `rd_data` và `rd_valid` phải hợp lệ trong khoảng từ ngay sau cạnh N đến trước cạnh N+1.

Nếu `rd_en == 1` nhưng `rd_accept == 0`:

- Không thay đổi `read_pointer`.
- `rd_valid` bằng 0.
- Giá trị `rd_data` được giữ nguyên.
- `underflow` bằng 1 trong chu kỳ sau cạnh lấy mẫu yêu cầu.

### 7.4. Đọc và ghi đồng thời

| Trạng thái trước cạnh clock | `wr_en` | `rd_en` | Ghi | Đọc | Thay đổi `data_count` | Kết quả |
|---|---:|---:|---|---|---:|---|
| Empty | 0 | 0 | Không | Không | 0 | Giữ nguyên |
| Empty | 0 | 1 | Không | Từ chối | 0 | `underflow=1` |
| Empty | 1 | 0 | Chấp nhận | Không | +1 | Lưu `wr_data` |
| Empty | 1 | 1 | Chấp nhận | Từ chối | +1 | Không bypass; `underflow=1` |
| Trung gian | 0 | 1 | Không | Chấp nhận | -1 | Trả phần tử đầu FIFO |
| Trung gian | 1 | 0 | Chấp nhận | Không | +1 | Thêm dữ liệu vào cuối FIFO |
| Trung gian | 1 | 1 | Chấp nhận | Chấp nhận | 0 | Đọc phần tử cũ, thêm phần tử mới |
| Full | 1 | 0 | Từ chối | Không | 0 | `overflow=1` |
| Full | 0 | 1 | Không | Chấp nhận | -1 | FIFO hết trạng thái full |
| Full | 1 | 1 | Chấp nhận | Chấp nhận | 0 | Duy trì full, không overflow |

Khi FIFO full, `read_pointer` và `write_pointer` có thể cùng chỉ tới một địa chỉ. Nếu đọc và ghi đồng thời tại địa chỉ đó, phía đọc phải nhận **dữ liệu cũ**, sau đó dữ liệu mới được lưu vào vị trí cuối FIFO. Đây là hành vi **read-before-write/read-first** bắt buộc.

### 7.5. Thứ tự dữ liệu

Giả sử ghi thành công theo thứ tự:

```text
A, B, C, D
```

Các phép đọc thành công phải trả về đúng thứ tự:

```text
A, B, C, D
```

Không được mất dữ liệu, lặp dữ liệu, đổi thứ tự hoặc trả dữ liệu từ yêu cầu ghi bị từ chối.

### 7.6. Cờ trạng thái

Cờ trạng thái phải phản ánh trạng thái FIFO sau cạnh clock gần nhất:

```text
empty = (data_count == 0)
full  = (data_count == DEPTH)
```

Các bất biến bắt buộc:

```text
0 <= data_count <= DEPTH
!(full && empty)
full  -> data_count == DEPTH
empty -> data_count == 0
```

### 7.7. Xung báo lỗi giao thức

```text
overflow  = wr_en && !wr_accept
underflow = rd_en && !rd_accept
```

`overflow` và `underflow` là các output đã đăng ký, có độ dài đúng một chu kỳ cho mỗi chu kỳ yêu cầu bị từ chối. Hai tín hiệu tự trở về 0 ở chu kỳ kế tiếp nếu không có lỗi mới.

## 8. Ví dụ hoạt động theo chu kỳ

Giả sử FIFO đang empty và reset đã được nhả:

| Cạnh clock | `wr_en`/`wr_data` | `rd_en` | Giao dịch | `data_count` sau cạnh | `rd_valid`/`rd_data` |
|---:|---|---:|---|---:|---|
| 1 | 1 / `8'h11` | 0 | Ghi `11` | 1 | 0 / giữ nguyên |
| 2 | 1 / `8'h22` | 0 | Ghi `22` | 2 | 0 / giữ nguyên |
| 3 | 0 / X | 1 | Đọc `11` | 1 | 1 / `8'h11` |
| 4 | 1 / `8'h33` | 1 | Đọc `22`, ghi `33` | 1 | 1 / `8'h22` |
| 5 | 0 / X | 1 | Đọc `33` | 0 | 1 / `8'h33` |
| 6 | 0 / X | 1 | Underflow | 0 | 0 / giữ `8'h33` |

## 9. Kiến trúc vi mô đề xuất

Khối FIFO gồm:

1. **Memory array**: `DEPTH × DATA_WIDTH` bit.
2. **Write pointer**: chỉ vị trí ghi kế tiếp.
3. **Read pointer**: chỉ phần tử cũ nhất chưa đọc.
4. **Occupancy counter**: theo dõi số phần tử hợp lệ.
5. **Control logic**: tạo `wr_accept`, `rd_accept`, cờ trạng thái và xung lỗi.
6. **Registered read output**: lưu dữ liệu đọc và phát `rd_valid`.

Với ASIC, memory phải cung cấp hành vi tương đương một cổng đọc và một cổng ghi trong cùng chu kỳ. Khi đọc–ghi trùng địa chỉ, macro memory hoặc logic bao quanh phải bảo đảm hành vi read-first theo mục 7.4.

## 10. Yêu cầu RTL

- RTL phải synthesizable bằng SystemVerilog.
- Sử dụng nonblocking assignment trong logic tuần tự.
- Không dùng delay `#`, `initial` để mô tả chức năng phần cứng hoặc cấu trúc không tổng hợp được.
- Không reset từng phần tử memory trừ khi công nghệ bắt buộc; reset chỉ xóa trạng thái điều khiển.
- Pointer chỉ thay đổi khi giao dịch tương ứng được chấp nhận.
- `data_count` chỉ cập nhật dựa trên `wr_accept` và `rd_accept`.
- Logic phải xử lý đúng `DEPTH` không phải lũy thừa của 2.
- Không để latch, multi-driver, combinational loop hoặc truy cập memory ngoài phạm vi `0` đến `DEPTH-1`.
- Kiểm tra tham số không hợp lệ trong simulation/elaboration.

## 11. Kế hoạch verification tối thiểu

| Test name | Chức năng kiểm tra | Kịch bản chính | Kết quả mong đợi |
|---|---|---|---|
| `test_reset` | Reset và trạng thái khởi tạo | Reset khi idle; reset khi FIFO có dữ liệu; reset khi đang full | Pointer/count/output control trở về trạng thái reset |
| `test_single_write_read` | Ghi và đọc cơ bản | Ghi một từ rồi đọc | Dữ liệu đọc đúng, count 0→1→0 |
| `test_fifo_order` | Tính FIFO | Ghi nhiều mẫu khác nhau rồi đọc hết | Dữ liệu ra đúng thứ tự ghi |
| `test_fill_to_full` | Biên full | Ghi đúng `DEPTH` phần tử | `full=1`, `data_count=DEPTH` |
| `test_overflow` | Chống ghi tràn | Ghi thêm khi full và không đọc | Ghi bị từ chối, state giữ nguyên, `overflow=1` |
| `test_drain_to_empty` | Biên empty | Đọc đến hết FIFO | `empty=1`, `data_count=0` |
| `test_underflow` | Chống đọc rỗng | Đọc khi empty | Đọc bị từ chối, `rd_valid=0`, `underflow=1` |
| `test_simultaneous_rw` | Đọc–ghi đồng thời | Cả hai enable tại occupancy trung gian | Count giữ nguyên, dữ liệu đúng thứ tự |
| `test_rw_when_full` | Throughput tại full | Full rồi bật cả `wr_en` và `rd_en` | Cả hai chấp nhận, đọc dữ liệu cũ, FIFO vẫn full |
| `test_rw_when_empty` | Quy tắc no-bypass | Empty rồi bật cả hai enable | Chỉ ghi thành công, đọc underflow |
| `test_pointer_wrap` | Quay vòng con trỏ | Nhiều lần ghi/đọc vượt quá `DEPTH` | Không truy cập sai địa chỉ, dữ liệu đúng |
| `test_random` | Stress toàn hệ thống | Random enable/data/reset với scoreboard | Không mất, lặp hoặc đảo thứ tự dữ liệu |
| `test_non_power_of_two_depth` | Tham số DEPTH tổng quát | Chạy với `DEPTH=5` hoặc `DEPTH=10` | Pointer wrap và flag chính xác |

Scoreboard nên sử dụng queue tham chiếu:

- Khi `wr_accept`, `push_back(wr_data)`.
- Khi `rd_accept`, `pop_front()` và so sánh với `rd_data` khi `rd_valid`.
- Sau mỗi cạnh clock, so sánh kích thước queue với `data_count`.

## 12. Assertions đề xuất

| Assertion | Thuộc tính cần kiểm tra |
|---|---|
| `A_RESET_STATE` | Sau cạnh clock có `rst_n=0`, FIFO ở trạng thái reset |
| `A_COUNT_RANGE` | `data_count` luôn nằm trong `[0, DEPTH]` |
| `A_FULL_EMPTY_EXCLUSIVE` | `full` và `empty` không đồng thời bằng 1 |
| `A_FULL_MATCH_COUNT` | `full` tương đương `data_count==DEPTH` |
| `A_EMPTY_MATCH_COUNT` | `empty` tương đương `data_count==0` |
| `A_WRITE_BLOCKED` | Ghi bị từ chối không làm đổi write pointer hoặc memory |
| `A_READ_BLOCKED` | Đọc bị từ chối không làm đổi read pointer và không tạo `rd_valid` |
| `A_WRITE_ONLY_COUNT` | Chỉ ghi hợp lệ làm count tăng 1 |
| `A_READ_ONLY_COUNT` | Chỉ đọc hợp lệ làm count giảm 1 |
| `A_RW_COUNT_STABLE` | Đọc và ghi cùng hợp lệ làm count giữ nguyên |
| `A_RD_VALID` | `rd_valid` chỉ xuất hiện khi chu kỳ lấy mẫu có đọc hợp lệ |
| `A_OVERFLOW_PULSE` | Yêu cầu ghi bị từ chối tạo đúng xung overflow |
| `A_UNDERFLOW_PULSE` | Yêu cầu đọc bị từ chối tạo đúng xung underflow |

Tính đúng thứ tự dữ liệu nên được kiểm tra bằng scoreboard hoặc assertion có mô hình queue tham chiếu, không chỉ bằng cờ trạng thái.

## 13. Functional coverage đề xuất

### Coverpoints

- Trạng thái occupancy: `0`, `1`, khoảng giữa, `DEPTH-1`, `DEPTH`.
- Tổ hợp `{wr_en, rd_en}`: idle, write-only, read-only, read+write.
- `overflow`: 0 và 1.
- `underflow`: 0 và 1.
- `rd_valid`: 0 và 1.
- Pointer wrap của cả read pointer và write pointer.
- Reset tại empty, occupancy trung gian và full.

### Cross coverage

- `occupancy_state × {wr_en, rd_en}`.
- `full × wr_en × rd_en`.
- `empty × wr_en × rd_en`.
- `pointer_wrap × operation`.

### Chuyển trạng thái quan trọng

- `empty -> non-empty`.
- `non-empty -> empty`.
- `not-full -> full`.
- `full -> not-full`.
- `full -> full` khi đọc–ghi đồng thời.

## 14. Tiêu chí hoàn thành

Thiết kế được xem là đạt khi:

- Pass toàn bộ directed tests và random regression.
- Không có assertion failure hợp lệ.
- Functional coverage đạt 100% các bins bắt buộc hoặc có waiver hợp lý.
- Scoreboard không phát hiện mất, lặp hoặc sai thứ tự dữ liệu.
- Lint không có lỗi nghiêm trọng: latch, multi-driver, width mismatch, out-of-range.
- Synthesis thành công với các cấu hình tối thiểu: `(DATA_WIDTH=8, DEPTH=16)` và một `DEPTH` không phải lũy thừa của 2.
- Static timing analysis đạt tần số mục tiêu của dự án.

## 15. Cấu hình tham chiếu cho bài tập RTL/DV

```text
Module      : sync_fifo
DATA_WIDTH  : 8 bit
DEPTH       : 16 entries
Capacity    : 128 bit
Clock       : 100 MHz mục tiêu ban đầu
Reset       : synchronous active-low
Read mode   : registered output, no fall-through
Throughput  : tối đa 1 write và 1 read mỗi clock
```

Tại 100 MHz, chu kỳ clock là 10 ns. Sau khi FIFO đã có dữ liệu, thiết kế có thể nhận một dữ liệu ghi và trả một dữ liệu đọc trong mỗi chu kỳ, tương đương thông lượng tối đa 100 triệu phần tử/giây trên từng hướng.
