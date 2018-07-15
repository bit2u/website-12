
import fs from 'fs'

API.add 'service/oab/scripts/blog_issue_rebuild',
  get: 
    roleRequired: 'root'
    action: () ->
      urls = []
      updates = []
      recs = JSON.parse(fs.readFileSync('/home/cloo/backups/oabutton_full_old_old_05032018.json'))

      old_ratings = JSON.parse(fs.readFileSync('/home/cloo/oabutton_ratings.csv'))
      story_ratings = {}
      for rate in old_ratings
        story_ratings[rate.Story.toLowerCase()] = rate

      new_ratings = JSON.parse(fs.readFileSync('/home/cloo/oabutton_ratings_withID_13072018.csv'))
      ratings = {}
      for rating in new_ratings
        ratings[rating._id] = rating

      for rec in recs.hits.hits
        rec = rec._source
        rec.type ?= 'article'
        if rec.type is 'article' and not rec.request? and rec.test isnt true and rec.story and urls.indexOf(rec.url) is -1 and not oab_request.get(rec._id)? and not oab_request.get({url:rec.url})?
          delete rec.email if rec.email is None or rec.email is 'None'
          if not rec.rating?
            if rec.story? and story_ratings[rec.story.toLowerCase()]?
              rec.rating = story_ratings[rec.story.toLowerCase()].Rating
            if ratings[rec._id]?
              rec.rating = ratings[rec._id].rating
          if rec.rating?
            rec.rating = parseInt(rec.rating) if typeof rec.rating is 'string'
            rec.rating = if rec.rating >= 3 then 1 else 0
          if not rec.email? or (rec.email.indexOf('cottagelabs.com') is -1 and rec.email.indexOf('joe@') is -1 and rec.email.indexOf('natalianorori') is -1 and rec.email.indexOf('n/a') is -1)
            urls.push rec.url
            rec.legacy ?= {}
            rec.legacy.blog_issue_reload = true
            if rec.metadata?
              if rec.metadata.journal?.name?
                if typeof rec.metadata.journal.name is 'string' and rec.metadata.journal.name.length > 1 and rec.metadata.journal.name.indexOf('\\') is -1 and rec.metadata.journal.name.indexOf('by ') isnt 0 and rec.metadata.journal.name.indexOf('info') isnt 0
                  rec.journal ?= rec.metadata.journal.name.trim()
              if rec.metadata.title? and rec.metadata.title.length > 1
                rec.title ?= rec.metadata.title
              if rec.metadata.identifier? and rec.metadata.identifier.length > 0 and rec.metadata.identifier[0].type? and rec.metadata.identifier[0].type.toLowerCase() is 'doi' and rec.metadata.identifier[0].id?
                rec.doi = rec.metadata.identifier[0].id
              if rec.metadata.author?
                for author in rec.metadata.author
                  if author.name? and author.name.indexOf('\\') is -1
                    rec.author ?= []
                    rec.author.push author
              delete rec.metadata
              delete rec.description if rec.description?
              if rec.coords_lat
                rec.location ?= {}
                rec.location.geo ?= {}
                rec.location.geo.lat = rec.coords_lat
                delete rec.coords_lat
              if rec.coords_lng
                rec.location ?= {}
                rec.location.geo ?= {}
                rec.location.geo.lon = rec.coords_lng
                delete rec.coords_lng
              rec.created_date = moment(rec.createdAt, "x").format("YYYY-MM-DD HHmm.ss") if not rec.created_date?
              if rec.user?
                if typeof rec.user is 'string'
                  uid = rec.user
                  rec.user = {}
                else
                  uid = rec.user.id
                user = API.accounts.retrieve uid
                if not user?
                  delete rec.user # keep the request but remove the user info
                else
                  rec.user.email ?= user.emails[0].address
                  rec.user.username ?= user.profile?.firstname ? user.username ? user.emails[0].address
                  rec.user.firstname ?= user.profile?.firstname
                  rec.user.lastname ?= user.profile?.lastname
                  rec.user.affiliation ?= user.service?.openaccessbutton?.profile?.affiliation
                  rec.user.profession ?= user.service?.openaccessbutton?.profile?.profession
              updates.push rec
      
      fs.writeFileSync '/home/cloo/oabutton_blog_issue_imports.json', JSON.stringify updates
      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'Blog issue rebuild complete'
        text: 'imports: ' + imports.length
      return {count: imports.length}



API.add 'service/oab/scripts/blog_issue_reload',
  get: 
    roleRequired: 'root'
    action: () ->
      imports = JSON.parse(fs.readFileSync('/home/cloo/oabutton_blog_issue_imports.json'))
      #API.es.import 'oab', 'request', imports, undefined, undefined, false
      #oab_request.import(imports) if imports.length > 0
      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'Blog issue reload complete'
        text: 'imports: ' + imports.length
      return {count: imports.length}
