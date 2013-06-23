mesa = require '../src/postgres'

module.exports =

    'implicit connection is closed on insert': (test) ->
        test.expect 1

        getConnection = (cb) ->
            process.nextTick ->
                done = -> test.ok true
                connection =
                    query: (sql, params, cb) ->
                        cb null, {rows: [{id: 3}]}
                cb null, connection, done

        userModel = mesa
            .connection(getConnection)
            .table('user')
            .attributes(['name'])

        userModel.insert {name: 'foo'}, (err, id) ->
            throw err if err?
            test.done()
