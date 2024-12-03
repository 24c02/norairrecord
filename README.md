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
* custom UA
  * `Norairrecord.user_agent = "i'm the reason why you're getting 429s!"`
* `Table#airtable_url`
  * what it says on the tin!