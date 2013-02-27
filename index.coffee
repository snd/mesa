_ = require 'underscore'
async = require 'async'
mohair = require('mohair').escape((string) -> "\"#{string}\"")

createCriterion = (pk, fk, records) ->
    criterion = {}
    criterion[fk] = _.unique _.pluck records, pk
    return criterion

setOneInclude = (name, pk, fk, records, associated) ->
    records.forEach (record) ->
        record[name] = _.detect associated, (x) -> record[fk] is x[pk]

setManyIncludes = (name, pk, fk, records, associated) ->
    records.forEach (record) ->
        record[name] = _.filter associated, (x) -> record[fk] is x[pk]

module.exports =

    # adapter
    # -------

    replacePlaceholders: (sql) ->
        # replace ?, ?, ... with $1, $2, ...
        index = 1
        sql.replace /\?/g, -> '$' + index++

    # default
    # --------

    _mohair: mohair
    _primaryKey: 'id'

    # setter
    # ------

    set: (key, value) ->
        object = Object.create @
        object[key] = value
        object

    table: (arg) -> @set('_table', arg).set '_mohair', @_mohair.table arg

    connection: (arg) -> @set '_connection', arg
    attributes: (arg) -> @set '_attributes', arg
    primaryKey: (arg) -> @set '_primaryKey', arg
    includes: (arg) -> @set '_includes', arg
    returning: (arg) ->
        throw new Error 'must be a string' unless 'string' is typeof arg
        throw new Error 'must not be the empty string' if arg.length is 0
        @set '_returning', arg

    where: (args...) -> @set '_mohair', @_mohair.where args...
    join: (args...) -> @set '_mohair', @_mohair.join args...

    select: (args...) -> @set '_mohair', @_mohair.select args...
    limit: (arg) -> @set '_mohair', @_mohair.limit arg
    offset: (arg) -> @set '_mohair', @_mohair.offset arg
    order: (arg) -> @set '_mohair', @_mohair.order arg
    group: (arg) -> @set '_mohair', @_mohair.group arg

    # getter
    # ------

    getConnection: (cb) ->
        connection = @_connection
        unless connection?
            throw new Error "the method you are calling requires a call to connection() before it"
        return connection cb if 'function' is typeof connection
        process.nextTick -> cb null, connection

    # command
    # -------

    insert: (data, cb) ->
        unless @_attributes?
            throw new Error 'insert() requires call to attributes() before it'

        cleanData = _.pick data, @_attributes
        if Object.keys(cleanData).length is 0
            throw new Error 'nothing to insert'

        query = @_mohair.insert cleanData
        returning = if @_returning then @_returning else @_primaryKey
        sql = @replacePlaceholders query.sql() + " RETURNING #{returning}"

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, query.params(), (err, results) =>
                return cb err if err?

                row = results.rows[0]

                cb null, if @_returning? then row else row[@_primaryKey]

    insertMany: (data, cb) ->
        unless @_attributes?
            throw new Error 'insertMany() requires call to attributes() before it'

        query = @_mohair.insert data.map (x) => _.pick x, @_attributes
        returning = if @_returning then @_returning else @_primaryKey
        sql = @replacePlaceholders query.sql() + " RETURNING #{returning}"

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, query.params(), (err, results) =>
                return cb err if err?

                cb null, if @_returning? then results.rows else _.pluck results.rows, @_primaryKey

    delete: (cb) ->
        query = @_mohair.delete()
        sql = @replacePlaceholders query.sql()

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, query.params(), cb

    update: (updates, cb) ->
        unless @_attributes?
            throw new Error 'update() requires call to attributes() before it'

        cleanUpdates = _.pick updates, @_attributes
        throw new Error 'nothing to update' if Object.keys(cleanUpdates).length is 0

        query =  @_mohair.update cleanUpdates
        sql = @replacePlaceholders query.sql()
        sql += " RETURNING #{@_returning}" if @_returning?

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, query.params(), (err, results) =>
                return cb err if err?
                return cb null, results unless @_returning?
                return cb null, results.rows

    # query
    # -----

    first: (cb) ->
        query =  @_mohair
        sql = @replacePlaceholders query.sql()

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, query.params(), (err, results) =>
                return cb err if err?

                record = results.rows[0]

                return cb null, null if not record?

                @_getIncludes connection, [record], (err, withIncludes) =>
                    return cb err if err?
                    cb null, withIncludes[0]

    find: (cb) ->
        query =  @_mohair
        sql = @replacePlaceholders query.sql()

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, query.params(), (err, results) =>
                return cb err if err?

                records = results.rows

                return cb null, [] if records.length is 0

                @_getIncludes connection, records, (err, withIncludes) =>
                    return cb err if err?

                    cb null, withIncludes

    exists: (cb) ->
        query =  @_mohair
        sql = @replacePlaceholders query.sql()

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, query.params(), (err, results) ->
                return cb err if err?

                cb null, results.rows.length isnt 0

    # association
    # -----------

    hasAssociated: (name, associationFun) ->
        associations = _.extend {}, @_associations
        associations[name] = associationFun
        @set '_associations', associations

    _getIncludes: (connection, records, cb) ->
        unless @_includes? then return process.nextTick -> cb null, records

        keys = Object.keys @_includes

        throw new Error 'empty includes' if keys.length is 0

        keys.forEach (key) =>
            unless @_associations? and @_associations[key]?
                throw new Error "no association: #{key}"

        getInclude = (key, cb) =>
            @_associations[key] connection, @_includes[key], records, cb

        async.forEachSeries keys, getInclude, (err) =>
            return cb err if err?
            cb null, records

    hasOne: (name, model, options) ->
        @hasAssociated name, (connection, subIncludes, records, cb) =>
            if 'function' is typeof model then model = model()
            model = model.connection connection
            model = model.includes subIncludes if 'object' is typeof subIncludes

            throw new Error 'no table set on model' unless @_table?
            throw new Error 'no table set on associated model' unless model._table?

            primaryKey = options?.primaryKey || @_primaryKey
            foreignKey = options?.foreignKey || "#{@_table}_#{@_primaryKey}"

            criterion = createCriterion primaryKey, foreignKey, records

            model.where(criterion).find (err, associated) ->
                return cb err if err?
                setOneInclude name, foreignKey, primaryKey, records, associated
                cb null, records

    hasMany: (name, model, options) ->
        @hasAssociated name, (connection, subIncludes, records, cb) =>
            if 'function' is typeof model then model = model()
            model = model.connection connection
            model = model.includes subIncludes if 'object' is typeof subIncludes

            throw new Error 'no table set on model' unless @_table?
            throw new Error 'no table set on associated model' unless model._table?

            primaryKey = options?.primaryKey || @_primaryKey
            foreignKey = options?.foreignKey || "#{@_table}_#{@_primaryKey}"

            criterion = createCriterion primaryKey, foreignKey, records

            model.where(criterion).find (err, associated) ->
                return cb err if err?
                setManyIncludes name, foreignKey, primaryKey, records, associated
                cb null, records

    belongsTo: (name, model, options) ->
        @hasAssociated name, (connection, subIncludes, records, cb) =>
            if 'function' is typeof model then model = model()
            model = model.connection connection
            model = model.includes subIncludes if 'object' is typeof subIncludes

            throw new Error 'no table set on model' unless @_table?
            throw new Error 'no table set on associated model' unless model._table?

            primaryKey = options?.primaryKey || @_primaryKey
            foreignKey = options?.foreignKey || "#{model._table}_#{model._primaryKey}"

            criterion = createCriterion foreignKey, primaryKey, records

            model.where(criterion).find (err, associated) ->
                return cb err if err?
                setOneInclude name, primaryKey, foreignKey, records, associated
                cb null, records

    hasAndBelongsToMany: (name, model, options) ->
        @hasAssociated name, (connection, subIncludes, records, cb) =>
            if 'function' is typeof model then model = model()
            model = model.connection connection
            model = model.includes subIncludes if 'object' is typeof subIncludes

            throw new Error 'no table set on model' unless @_table?
            throw new Error 'no table set on associated model' unless model._table?

            joinTable = options?.joinTable
            throw new Error 'no join table' unless joinTable?

            primaryKey = options.primaryKey || @_primaryKey
            foreignKey = options.foreignKey || "#{@_table}_#{@_primaryKey}"

            otherPrimaryKey = options.otherPrimaryKey || model._primaryKey
            otherForeignKey = options.otherForeignKey || "#{model._table}_#{model._primaryKey}"

            intersectionCriterion =
                createCriterion primaryKey, foreignKey, records

            query = mohair.table(joinTable).where(intersectionCriterion)
            sql = @replacePlaceholders query.sql()

            connection.query sql, query.params(), (err, results) ->
                return cb err if err?

                intersection = results.rows

                return cb null, records if intersection.length is 0

                criterion =
                    createCriterion otherForeignKey, otherPrimaryKey, intersection

                model.where(criterion).find (err, associated) ->
                    return cb err if err?

                    records.forEach (record) ->
                        relevantIntersection = _.filter intersection, (x) ->
                            x[foreignKey] is record[primaryKey]
                        otherPrimaryKeys = _.pluck relevantIntersection, otherForeignKey
                        record[name] = associated.filter (x) ->
                            x[otherPrimaryKey] in otherPrimaryKeys

                    cb null, records
