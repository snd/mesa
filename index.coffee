mohair = require('mohair').escapeTableName((tableName) -> "\"#{tableName}\"")
_ = require 'underscore'
async = require 'async'

postgresPlaceholders = (sql) ->
    # replace ?, ?, ... with $1, $2, ...
    index = 1
    sql.replace /\?/g, -> '$' + index++

module.exports =

    set: (key, value) ->
        object = Object.create @
        object[key] = value
        object

    table: (table) -> @set('_table', table).set '_mohair', @_mohair.table table

    connection: (connection) -> @set '_connection', connection

    attributes: (attributes) -> @set '_attributes', attributes

    getConnection: (cb) ->
        connection = @_connection
        unless connection?
            throw new Error "the method you are calling requires call to connection() before it"
        return connection cb if 'function' is typeof connection
        process.nextTick -> cb null, connection

    _mohair: mohair

    where: (args...) -> @set '_mohair', @_mohair.where args...
    select: (arg) -> @set '_mohair', @_mohair.select arg
    join: (args...) -> @set '_mohair', @_mohair.join args...
    limit: (arg) -> @set '_mohair', @_mohair.limit arg
    offset: (arg) -> @set '_mohair', @_mohair.offset arg
    order: (arg) -> @set '_mohair', @_mohair.order arg
    group: (arg) -> @set '_mohair', @_mohair.group arg

    # commands
    # --------

    insert: (data, cb) ->
        unless @_attributes?
            throw new Error 'insert() requires call to attributes() before it'

        cleanData = _.pick data, @_attributes
        if Object.keys(cleanData).length is 0
            throw new Error 'nothing to insert'

        m = @_mohair.insert cleanData
        sql = @postgresPlaceholders m.sql() + ' RETURNING id'
        params = m.params()

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, params, (err, results) ->
                return cb err if err?

                cb null, results.rows[0].id

    insertMany: (data, cb) ->
        unless @_attributes?
            throw new Error 'insertMany() requires call to attributes() before it'

        attributes = @_attributes
        m = @_mohair.insert data.map (x) -> _.pick x, attributes
        sql = @postgresPlaceholders m.sql() + ' RETURNING id'
        params = m.params()

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, params, (err, results) ->
                return cb err if err?

                cb null, _.pluck results.rows, 'id'

    delete: (cb) ->
        m = @_mohair.delete()
        sql = @postgresPlaceholders m.sql()
        params = m.params()

        @getConnection (err, connection) ->
            return cb err if err?
            connection.query sql, params, cb

    update: (data, cb) ->
        unless @_attributes?
            throw new Error 'update() requires call to attributes() before it'

        if Object.keys(data).length is 0
            throw new Error 'empty updates'

        m = @_mohair.update _.pick data, @_attributes
        sql = @postgresPlaceholders m.sql()
        params = m.params()

        @getConnection (err, connection) =>
            return cb err if err?
            connection.query sql, params, cb

    # queries
    # -------

    first: (cb) ->
        sql = @postgresPlaceholders @_mohair.sql()
        params = @_mohair.params()

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, params, (err, results) =>
                return cb err if err?

                item = results.rows[0]

                return cb null, null if not item?

                @fetchIncludes connection, [item], (err, withIncludes) =>
                    return cb err if err?
                    cb null, withIncludes[0]

    find: (cb) ->
        sql = @postgresPlaceholders @_mohair.sql()
        params = @_mohair.params()

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, params, (err, results) =>
                return cb err if err?

                items = results.rows

                return cb null, [] if items.length is 0

                @fetchIncludes connection, items, (err, withIncludes) =>
                    return cb err if err?

                    cb null, withIncludes

    exists: (cb) ->
        sql = @postgresPlaceholders @_mohair.sql()
        params = @_mohair.params()

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, params, (err, results) ->
                return cb err if err?
                cb null, results.rows.length isnt 0

    # associations
    # ------------

    includes: (includes) -> @set '_includes', includes

    _addAssociation: (type, name, model, options) ->
        associations = _.extend {}, @_associations
        associations[name] =
            type: type
            model: model
            options: options
        @set '_associations', associations

    hasOne: (name, model, options) ->
        @_addAssociation 'hasOne', name, model, options

    belongsTo: (name, model, options) ->
        @_addAssociation 'belongsTo', name, model, options

    hasMany: (name, model, options) ->
        @_addAssociation 'hasMany', name, model, options

    hasAndBelongsToMany: (name, model, options) ->
        @_addAssociation 'hasAndBelongsToMany', name, model, options

    fetchIncludes: (connection, items, cb) ->
        return cb null, items unless @_includes?

        includeNames = Object.keys(@_includes)

        throw new Error 'empty includes' if includeNames.length is 0

        associations = @_associations
        table = @_table
        includes = @_includes

        includeNames.forEach (x) ->
            unless associations? and associations[x]?
                throw new Error "no association: #{x}"

        throw new Error 'no table set on model' unless table?

        fetchInclude = (includeName, cb) ->

            assoc = associations[includeName]

            otherModel =
                if 'function' is typeof assoc.model then assoc.model() else assoc.model
            otherTable = otherModel._table
            throw new Error 'no table set on associated model' unless otherTable?

            chain = otherModel.connection connection

            # fetch nested includes
            if 'object' is typeof includes[includeName]
                chain = chain.includes includes[includeName]

            fetchDirect = (key, otherKey, filter, cb) ->
                criterion = {}
                criterion[otherKey] = _.unique _.pluck items, key

                chain.where(criterion).find (err, associated) ->
                    return cb err if err?

                    items.forEach (item) ->
                        item[includeName] = filter associated, (x) ->
                            x[otherKey] is item[key]
                    cb null, items

            primaryKey = assoc.options?.primaryKey || 'id'
            foreignKey = assoc.options?.foreignKey

            switch assoc.type
                when 'hasOne'
                    fetchDirect primaryKey, (foreignKey || "#{table}_id"), _.detect, cb
                when 'hasMany'
                    fetchDirect primaryKey, (foreignKey || "#{table}_id"), _.filter, cb
                when 'belongsTo'
                    fetchDirect (foreignKey || "#{otherTable}_id"), primaryKey, _.detect, cb
                when 'hasAndBelongsToMany'
                    joinTable = assoc.options.joinTable
                    throw new Error 'no join table' unless joinTable?

                    foreignKey ?= "#{table}_id"
                    intersectionCriterion = {}
                    intersectionCriterion[foreignKey] = _.pluck items, primaryKey
                    m = mohair.table(joinTable).where(intersectionCriterion)
                    sql = postgresPlaceholders m.sql()
                    connection.query sql, m.params(), (err, results) ->
                        return cb err if err?

                        intersection = results.rows

                        otherPrimaryKey = assoc.options?.otherPrimaryKey || 'id'
                        otherForeignKey = assoc.options?.otherForeignKey || "#{otherTable}_id"

                        criterion = {}
                        criterion[otherPrimaryKey] =
                            _.unique _.pluck intersection, otherForeignKey

                        chain.where(criterion).find (err, associated) ->
                            return cb err if err?
                            items.forEach (item) ->
                                relevantIntersection = _.filter intersection, (x) ->
                                    x[foreignKey] is item[primaryKey]
                                otherPrimaryKeys = _.pluck relevantIntersection, otherForeignKey
                                item[includeName] = associated.filter (x) ->
                                    x[otherPrimaryKey] in otherPrimaryKeys
                            cb null, items
                else
                    throw new Error "unknown association type: #{assoc.type}"

        async.forEachSeries includeNames, fetchInclude, (err) ->
            return cb err if err?
            cb null, items

    postgresPlaceholders: postgresPlaceholders
