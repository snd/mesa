Promise = require 'bluebird'

{setup, teardown, mesa} = require './src/common'

module.exports =

  'setUp': setup
  'tearDown': teardown

  'advisory locks and transactions (long version)': (test) ->
    test.expect 2 + 5 + 4 + 3 + 2 + 1

    bitcoinReceiveAddress = mesa.table('bitcoin_receive_address')

    # see this:
    # http://postgres.cz/wiki/PostgreSQL_SQL_Tricks#Taking_first_unlocked_row_from_table
    # http://stackoverflow.com/questions/9809381/hashing-a-string-to-a-numeric-value-in-postgressql

    sqlTohashIdToBigint = "('x'||substr(md5(id),1,16))::bit(64)::bigint"

    addressPromises = [700, 600, 500, 400, 300, 200, 100].map (delay) ->
      mesa.wrapInTransaction (transaction) ->
        withTransaction = bitcoinReceiveAddress.setConnection transaction
        withTransaction
          .select(
            '*'
            # TODO remove this
            {hash: sqlTohashIdToBigint}
          )
          # this gives us the id the first row that is not locked:
          # pg_try_advisory_xact_lock(arg) acquires an exclusive
          # lock for this transaction and this `arg`.
          # this means that no other transaction can acquire a lock for this `arg`
          # (pg_try_advisory_xact_lock would return false) until the
          # end of the transaction.
          # the "xact" part means that the lock is per transaction
          # (instead of per connection)
          # and the lock is released at the end of the transaction.
          # `arg` must be an integer (4 bytes) or bigint (8 bytes).
          # the `id` column is a 34 byte text.
          # we convert id into a bigint by computing the md5 hash,
          # taking the first 16 bytes of the md5 hash,
          # casting them to a sequence of 16 * 
          # TODO finish
          # 
          # the scanner will do a linear scan through the rows and
          # check the where condition for each row.
          # it will effectively skip locked rows as pg_try_advisory_xact_lock
          # returns false for them.
          # as soon as pg_try_advisory_xact_lock returns true we have
          # an exclusive lock for that row.
          # since we limit our results to 1 no further where conditions
          # will be checked, no further locks acquired and the one row
          # is returned.

          .where("pg_try_advisory_xact_lock(#{sqlTohashIdToBigint})")
          .limit(1)
          .first()
          .then (address) ->
            unless address?
              return
            # if we have an `address` here then we can be sure that
            # we have an exclusive lock on the id and no other transaction
            # will execute the following code with the same id.
            # this means that we delete and return an exclusive address !
            # if we have no `address` here no addresses are left for which
            # we can get an exclusive lock

            # sleep a while to ensure that all locks are in place

            Promise.delay(delay).then ->
              withTransaction
                .where(id: address.id)
                .returnFirst()
                .delete()
                .then ->
                  address

    Promise.all(addressPromises).then (addresses) ->
      test.equal 7, addresses.length
      existing = []
      addresses.forEach (address) ->
        if address?
          test.equal 34, address.id.length
          existing.forEach (existing) ->
            test.notEqual address.id, existing.id
          existing.push address
      test.equal 5, existing.length
      test.done()

  'advisory locks (short subquery version)': (test) ->
    test.expect 2 + 5 + 4 + 3 + 2 + 1

    # for further information see the test immediately above

    bitcoinReceiveAddress = mesa.table('bitcoin_receive_address')

    sqlTohashIdToBigint = "('x'||substr(md5(id),1,16))::bit(64)::bigint"

    # the subquery is executed first, acquires an exclusive lock for a row
    # and returns its id.
    addressPromises = [1..7].map ->
      idOfLockedAddress = bitcoinReceiveAddress
        .select('id')
        .where("pg_try_advisory_xact_lock(#{sqlTohashIdToBigint})")
        .limit(1)

      bitcoinReceiveAddress
        .where(id: idOfLockedAddress)
        .returnFirst()
        .delete()

    Promise.all(addressPromises).then (addresses) ->
      test.equal 7, addresses.length
      existing = []
      addresses.forEach (address) ->
        if address?
          test.equal 34, address.id.length
          existing.forEach (existing) ->
            test.notEqual address.id, existing.id
          existing.push address
      test.equal 5, existing.length
      test.done()
