Description: Trello Task 1b

Scenario: Use API for Trello Board creation
Given request body: {
 "key": "1b67ec7caf17565d1d7d31c33aa8d40b",
 "token": "462fe838471839fd491741f7a43679114f20aaa25573de621226a908f8dda477",
 "name": "Tesst"
}
When I send HTTP POST to the relative URL '/boards/?key=1b67ec7caf17565d1d7d31c33aa8d40b&token=462fe838471839fd491741f7a43679114f20aaa25573de621226a908f8dda477&name=Randomizer'
Then the response code is equal to '200'
