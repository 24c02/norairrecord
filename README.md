# Norairrecord

[airrecord](https://github.com/sirupsen/airrecord) : norairrecord :: epinephrine : norepinephrine

stuff not in the OG:
* `Table#comment`
  * ```ruby
    rec.comment "pretty cool record!"
    ```
* `Table#patch`!
  * ```ruby
    rec.patch({ # this will fire off a request 
      "field 1" => "new value 1", # that only modifies
      "field 2" => "new value 2", # the specified fields
    })
    ```
* """""transactions"""""!
  * they're not great but they kinda do a thing!
  * ```ruby
    rec.transaction do |rec| # pipes optional
      # do some stuff to rec...
      # all changes inside the block happen in 1 request
      # none of the changes happen if an error is hit
    end
    ```
* custom endpoint URL
  * handy for inspecting/ratelimiting
  * `Norairrecord.base_url = "https://somewhere_else"`
  * or `ENV['AIRTABLE_ENDPOINT_URL']`
* custom UA
  * `Norairrecord.user_agent = "i'm the reason why you're getting 429s!"`
* `Table#airtable_url`
  * what it says on the tin!
* `Table.has_subtypes`
  * hokay so: 
  * ```ruby
    class Friend < Norairrecord::Table
      # base_key/table_name, etc...
      has_subtypes "type", { # based on 'type' column...
        "person" => "Person", # when 'person' instantiate record as Person 
        "shark" => "Shark"
      }, strict: true # if strict, unmapped types will raise UnknownTypeError
      # otherwise they will be instantiated as the base class
    end

    class Person < Friend; end
    class Shark < Friend; end
    
    Friend.all
    => [<Person>, <Person>, <Shark>]
    ```
* `Norairrecord::RecordNotFoundError`
  * never again wonder if an error is because you goofed up an ID or you're getting ratelimited
* `where` argument on `has_many` lookups
* `Table#first`, `Table#first_where`