/// 1주일 생존 여행 회화 카탈로그. UI는 영어 고정이므로 라벨은 영어만 둔다.
class Subtopic {
  const Subtopic(this.id, this.labelEn, this.promptHint);

  final String id;
  final String labelEn;
  final String promptHint;
}

class PhraseCategory {
  const PhraseCategory(this.id, this.labelEn, this.subtopics);

  final String id;
  final String labelEn;
  final List<Subtopic> subtopics;
}

const kPhraseCatalog = <PhraseCategory>[
  PhraseCategory('basics', 'Basic Expressions', [
    Subtopic(
      'greeting',
      'Greetings',
      'exchanging everyday greetings with a local',
    ),
    Subtopic(
      'introduction',
      'Introducing yourself',
      'a traveler briefly introducing themselves to a local',
    ),
    Subtopic(
      'asking',
      'Asking questions',
      'politely asking a stranger a simple question',
    ),
    Subtopic(
      'answering',
      'Answering',
      'giving short natural answers to simple questions',
    ),
    Subtopic(
      'confirming',
      'Confirming',
      'double-checking that you understood something correctly',
    ),
    Subtopic(
      'requesting',
      'Making requests',
      'politely asking someone for a small favor',
    ),
    Subtopic(
      'complimenting',
      'Compliments',
      'complimenting food, places, or service and responding to thanks',
    ),
  ]),
  PhraseCategory('inflight', 'In-flight', [
    Subtopic(
      'boarding',
      'Boarding & departure',
      'boarding the plane and preparing for departure',
    ),
    Subtopic(
      'seat',
      'Finding your seat',
      'finding your seat and asking to swap or pass by',
    ),
    Subtopic(
      'inflight-service',
      'Meals & service requests',
      'receiving meal/drink service and requesting help, including urgent or medical needs',
    ),
    Subtopic(
      'arrival-card',
      'Arrival card',
      'asking how to fill out the arrival/immigration card',
    ),
  ]),
  PhraseCategory('airport', 'Airport', [
    Subtopic(
      'immigration',
      'Immigration',
      'answering immigration officer questions about purpose and length of stay',
    ),
    Subtopic(
      'baggage',
      'Baggage claim',
      'finding the carousel and reporting missing baggage',
    ),
    Subtopic(
      'customs',
      'Customs',
      'declaring items and answering customs questions',
    ),
    Subtopic(
      'currency-exchange',
      'Currency exchange',
      'exchanging money and asking about rates and fees',
    ),
    Subtopic(
      'airport-transport',
      'Airport transportation',
      'asking how to get to the city center by bus, train, or taxi',
    ),
  ]),
  PhraseCategory('hotel', 'Hotel', [
    Subtopic(
      'accommodation-types',
      'Types of accommodation',
      'asking about room types, rates, and what is included',
    ),
    Subtopic(
      'check-in',
      'Check-in (with or without a reservation)',
      'checking in with a reservation, or asking for a room without one',
    ),
    Subtopic(
      'room-service',
      'Room service',
      'ordering room service and asking for amenities',
    ),
    Subtopic(
      'front-desk',
      'Asking the front desk',
      'asking the front desk about wifi, breakfast, luggage storage, or problems with the room',
    ),
    Subtopic(
      'check-out',
      'Check-out',
      'checking out, settling the bill, and asking to store luggage',
    ),
  ]),
  PhraseCategory('restaurant', 'Restaurant', [
    Subtopic(
      'finding',
      'Finding a restaurant',
      'asking a local to recommend a place to eat nearby',
    ),
    Subtopic(
      'reservation',
      'Reservation',
      'booking a table and stating party size and time',
    ),
    Subtopic(
      'menu',
      'Choosing from the menu',
      'asking what a dish is and requesting a recommendation',
    ),
    Subtopic(
      'ordering',
      'Ordering',
      'ordering dishes and drinks, asking about spiciness or allergens',
    ),
    Subtopic(
      'dining',
      'During the meal',
      'asking for water, side dishes, utensils, or more of something',
    ),
    Subtopic(
      'fast-food',
      'Fast food',
      'ordering a set menu at a fast-food counter, to go or eat in',
    ),
    Subtopic(
      'cafe',
      'Café',
      'ordering coffee and dessert, asking for size and iced/hot',
    ),
    Subtopic(
      'izakaya',
      'Sushi bar / izakaya / pub',
      'ordering at a conveyor-belt sushi bar, izakaya, or local pub',
    ),
    Subtopic(
      'paying',
      'Paying',
      'asking for the bill, splitting it, and paying by card or cash',
    ),
  ]),
  PhraseCategory('transport', 'Transportation', [
    Subtopic(
      'bus',
      'Bus',
      'asking which bus to take, fares, and where to get off',
    ),
    Subtopic(
      'subway',
      'Subway',
      'buying a ticket or transit card and finding the right line and exit',
    ),
    Subtopic(
      'taxi',
      'Taxi',
      'telling the driver a destination and asking about the fare',
    ),
    Subtopic(
      'train',
      'Train',
      'buying intercity train tickets, reserved vs non-reserved seats, platforms',
    ),
    Subtopic(
      'car-rental',
      'Car rental',
      'renting a car, insurance options, and returning the car',
    ),
  ]),
  PhraseCategory('sightseeing', 'Sightseeing', [
    Subtopic(
      'tourist-info',
      'Tourist information center',
      'asking for maps, recommendations, and opening hours',
    ),
    Subtopic(
      'directions',
      'Asking for directions',
      'asking how to get to a landmark on foot or by transit',
    ),
    Subtopic(
      'at-the-sights',
      'At the sights',
      'buying admission tickets and asking about tours and exhibits',
    ),
    Subtopic(
      'photos',
      'Photos & video',
      'asking someone to take your photo and whether filming is allowed',
    ),
  ]),
  PhraseCategory('shopping', 'Shopping', [
    Subtopic(
      'finding-shops',
      'Finding shops',
      'asking where to buy something and where a market or mall is',
    ),
    Subtopic(
      'phrases',
      'Common shopping phrases',
      'asking to see items, sizes, colors, and trying things on',
    ),
    Subtopic(
      'bargaining',
      'Bargaining',
      'negotiating a lower price politely at a market',
    ),
    Subtopic(
      'paying',
      'Paying',
      'asking the price, tax refund, and paying by card or cash',
    ),
    Subtopic(
      'department-store',
      'Department store',
      'finding a floor or brand and asking about gift wrapping',
    ),
    Subtopic(
      'electronics',
      'Electronics store',
      'asking about specs, voltage, warranty, and tax-free purchase',
    ),
    Subtopic(
      'clothing',
      'Clothing store',
      'asking for sizes, fitting rooms, and different colors',
    ),
    Subtopic(
      'convenience-store',
      'Convenience store',
      'paying at the register, heating food, and asking for a bag',
    ),
    Subtopic(
      'bookstore',
      'Bookstore',
      'looking for a book, a section, or a magazine',
    ),
    Subtopic(
      'exchange-refund',
      'Exchange & refund',
      'exchanging or refunding an item with a receipt',
    ),
  ]),
  PhraseCategory('facilities', 'Public Facilities', [
    Subtopic(
      'phone',
      'Phone',
      'buying a SIM card and asking to borrow or use a phone',
    ),
    Subtopic('restroom', 'Restroom', 'asking where the nearest restroom is'),
    Subtopic(
      'post-office',
      'Post office',
      'sending a package or postcard abroad and asking about postage',
    ),
    Subtopic(
      'bank',
      'Bank',
      'using an ATM and exchanging money at a bank counter',
    ),
  ]),
  PhraseCategory('emergency', 'Emergency', [
    Subtopic(
      'lost-stolen',
      'Loss & theft',
      'reporting a lost or stolen item to police or staff',
    ),
    Subtopic(
      'traffic-accident',
      'Traffic accident',
      'reporting a traffic accident and asking for help',
    ),
    Subtopic(
      'health',
      'Health problems',
      'describing symptoms at a pharmacy or hospital',
    ),
  ]),
  PhraseCategory('return', 'Return Trip', [
    Subtopic(
      'flight-booking',
      'Booking & changing flights',
      'confirming, changing, or rebooking a return flight',
    ),
    Subtopic(
      'departure',
      'Departure procedures',
      'checking in at the airport, baggage, security, and boarding',
    ),
    Subtopic(
      'delays',
      'Delays & cancellations',
      'asking about a delayed or cancelled flight and rebooking options',
    ),
  ]),
];

PhraseCategory findCategory(String id) => kPhraseCatalog.firstWhere(
  (category) => category.id == id,
  orElse: () => throw ArgumentError('unknown category: $id'),
);

Subtopic findSubtopic(String categoryId, String subtopicId) =>
    findCategory(categoryId).subtopics.firstWhere(
      (subtopic) => subtopic.id == subtopicId,
      orElse: () =>
          throw ArgumentError('unknown subtopic: $categoryId/$subtopicId'),
    );
