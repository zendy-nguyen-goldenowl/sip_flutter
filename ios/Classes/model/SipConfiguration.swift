import Foundation
import linphonesw


class SipConfiguaration: Decodable {
    
    var username: String!
    var password: String!
    var domain: String!
    
    private enum CodingKeys : String, CodingKey {
        case username, password, domain
    }
}
