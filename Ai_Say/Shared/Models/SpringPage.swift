import Foundation

// 对应 Spring Boot 的 Page<T> 结构
struct SpringPage<T: Decodable>: Decodable {
    let content: [T]
    let totalPages: Int
    let totalElements: Int
    let last: Bool
    let size: Int
    let number: Int
}