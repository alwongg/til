import Foundation

let payload = ["42", "not-a-number", "108", " 7 ", "oops"]

let parsedIDs = payload.compactMap { raw -> Int? in
    // I reach for compactMap when parsing and filtering are really one decision.
    // It keeps the intent honest: keep only values that survived the transform.
    Int(raw.trimmingCharacters(in: .whitespaces))
}

print(parsedIDs) // [42, 108, 7]

let sameResultWithMoreSteps = payload
    .map { $0.trimmingCharacters(in: .whitespaces) }
    .filter { Int($0) != nil }
    .map { Int($0)! }

print(sameResultWithMoreSteps) // [42, 108, 7]

struct UserDTO {
    let id: String?
}

let users = [UserDTO(id: "1"), UserDTO(id: nil), UserDTO(id: "3")]
let userIDs = users.compactMap(\.id)
print(userIDs) // ["1", "3"]

// My rule: if map can naturally return nil for bad input, compactMap usually reads better
// than filter + map because it removes the temporary invalid state from the pipeline.
