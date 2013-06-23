mesa = require '../src/postgres'

module.exports =

    'implicit connection is closed on insert': (test) ->
        test.expect 4

        getConnection = (cb) ->
            process.nextTick ->
                done = -> test.ok true
                connection =
                    query: (sql, params, cb) ->
                        test.equal sql, 'INSERT INTO "user"("name") VALUES ($1) RETURNING id'
                        test.deepEqual params, ['foo']
                        cb null, {rows: [{id: 3}]}
                cb null, connection, done

        userModel = mesa
            .connection(getConnection)
            .table('user')
            .attributes(['name'])

        userModel.insert {name: 'foo'}, (err, id) ->
            throw err if err?
            test.equal id, 3
            test.done()
