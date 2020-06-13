# docs: https://github.com/reddit-archive/reddit/wiki/OAuth2#application-only-oauth
# docs: https://www.reddit.com/dev/api

token_type = localStorage.token_type || ''
access_token = localStorage.access_token || ''
token_expire_date = localStorage.token_expire_date || 0
refresh_api_access_token = () ->
    body = new FormData()
    body.append('grant_type', 'https://oauth.reddit.com/grants/installed_client')
    body.append('device_id', 'DO_NOT_TRACK_THIS_DEVICE')
    fetch('https://www.reddit.com/api/v1/access_token', {
        method: 'POST'
        headers:
            'Authorization': 'Basic SjZVcUg0a1lRTkFFVWc6'
        body
    }).then((response) ->
        response.json()
    ).then((json_data) ->
        { token_type, access_token, expires_in } = json_data
        token_expire_date = Date.now() + expires_in * 999
        localStorage.token_type = token_type
        localStorage.access_token = access_token
        localStorage.token_expire_date = token_expire_date
    )

api_op = (http_method, resource_path) ->
    # If access token is already expired, block while getting a new one.
    # If access token is expiring soon, don't block the current operation, but pre-emptively request a new token.
    if Date.now() > token_expire_date
        await refresh_api_access_token()
    else if Date.now() > token_expire_date - 600000
        refresh_api_access_token()
    fetch(
        'https://oauth.reddit.com/' + resource_path + (if resource_path.includes('?') then '&' else '?') + 'raw_json=1' ,
        {
            method: http_method
            headers:
                'Authorization': "#{token_type} #{access_token}"
        }
    ).then((response) ->
        response.json()
    )

import { titlecase_gfycat_video_id } from './tools.coffee'
process_post = (post) ->
    if not post.link_flair_text then post.link_flair_text = ''
    if post.is_self
            post.type = 'text'
            post.source = if post.selftext_html then post.selftext_html[31...-20] else ''
        else if post.domain.endsWith 'reddit.com'
            post.type = 'reddit'
            [_, _, _, _, _, _, id, _, comment_id, options] = post.url.split '/'
            url_params = new URLSearchParams(options)
            post.source = {
                id
                comment_id
                context_level: url_params.get('context')
            }
        else if post.url
            filetype = ''
            [i, j, k] = [post.url.indexOf('.', post.url.indexOf('/', post.url.indexOf('//') + 2) + 1), post.url.indexOf('?'), post.url.indexOf('#')]
            if j > -1
                filetype = post.url[(i + 1)...j]
            else if k > -1
                filetype = post.url[(i + 1)...k]
            else if i > -1
                filetype = post.url[(i + 1)...]
            switch filetype
                when 'jpg', 'png', 'gif'
                    post.type = 'image'
                    post.source = post.url
                when 'gifv'
                    post.type = 'audiovideo'
                    post.source = {
                        video: post.url[0...post.url.lastIndexOf('.')] + '.mp4'
                    }
                else
                    switch post.domain
                        when 'gfycat.com'
                            post.type = 'audiovideo'
                            post.source = {
                                video: 'https://giant.gfycat.com/' + titlecase_gfycat_video_id(post.url[(post.url.lastIndexOf('/') + 1)...]) + '.webm'
                            }
                        when 'imgur.com'
                            post.type = 'image'
                            post.source = post.url + '.jpg'
                        when 'redgifs.com'
                            post.type = 'audiovideo'
                            post.source = {
                                video: 'https://thumbs1.redgifs.com/' + titlecase_gfycat_video_id(post.url[(post.url.lastIndexOf('/') + 1)...]) + '.webm'
                            }
                        when 'v.redd.it'
                            post.type = 'audiovideo'
                            post.source = {
                                audio: post.secure_media.reddit_video.fallback_url[...post.secure_media.reddit_video.fallback_url.lastIndexOf('/')] + '/audio'
                                video: post.secure_media.reddit_video.fallback_url.split('?')[0]
                                mini_video: post.secure_media.reddit_video.scrubber_media_url
                            }
                        when 'youtube.com', 'youtu.be' 
                            post.type = 'embed'
                            post.source = post.secure_media.oembed.html
                        else
                            post.type = 'link'
                            post.source = post.url
        else
            post.type = 'unknown'
            post.source = ''
    if typeof post.source is 'string' and post.source.startsWith 'http://'
        post.source = 'https://' + post.source[7...]
    post
get_feed_fragment = (feed_config, num_posts) ->
    load = api_op('GET',
        (if feed_config.name is ''
            "#{feed_config.rank_by.type}?"
        else
            (if feed_config.type is 'user'
                "user/#{feed_config.name}?sort=#{feed_config.rank_by.type}&"
            else
                "r/#{feed_config.name}/#{feed_config.rank_by.type}?"
            )
        ) +
        (if feed_config.rank_by.type is 'top' then "t=#{feed_config.rank_by.filter}&" else '') +
        (if feed_config.last_seen then "after=#{feed_config.last_seen}&" else '') +
        (if feed_config.seen_count then "count=#{feed_config.seen_count}&" else '') +
        "limit=#{num_posts}"
    )
    [0...num_posts].map (i) ->
        load.then ({ data }) -> process_post data.children[i].data
export load_feed = (feed_config) ->
    stage_1 = get_feed_fragment(feed_config, 1)
    stage_2 = get_feed_fragment(feed_config, 4)
    stage_3 = get_feed_fragment(feed_config, 16)
    [
        Promise.race([stage_1[0], stage_2[0], stage_3[0]])
        Promise.race([stage_2[1], stage_3[1]])
        Promise.race([stage_2[2], stage_3[2]])
        Promise.race([stage_2[3], stage_3[3]])
        stage_3[4]
        stage_3[5]
        stage_3[6]
        stage_3[7]
        stage_3[8]
        stage_3[9]
        stage_3[10]
        stage_3[11]
        stage_3[12]
        stage_3[13]
        stage_3[14]
        stage_3[15]
    ]

process_replies = (replies_listing) ->
    if not replies_listing.data # No replies
        []
    else if replies_listing.data.children[0].data.count is 0 # Sometimes reddit fucks up and gives us a "more" with nothing in it
        []
    else replies_listing.data.children.map (child) ->
        if child.kind is 'more'
            {
                ...child.data
                body: ''
                is_more: true
                replies: []
                score_per_hour: 0
            }
        else
            {
                ...child.data
                body_html: child.data.body_html[16...-6]
                is_more: false
                replies: process_replies child.data.replies
                score: child.data.score - 1 # Don't count the built-in upvote from the commenter
                score_per_hour: (child.data.score - 1) * 3600 / (Date.now() / 1000 - child.data.created_utc)
            }
subtree_score_per_hour = (comment) ->
    Math.abs(comment.score_per_hour) + comment.replies.reduce(((sum, reply) -> sum + subtree_score_per_hour(reply)), 0)
subtree_character_count = (comment) ->
    comment.body.length + comment.replies.reduce(((sum, reply) -> sum + subtree_character_count(reply)), 0)
set_interest_properties = (total_score_per_hour, total_character_count, comment) ->
    if not comment.is_more
        comment.score_per_hour_percentage = Math.trunc(comment.score_per_hour / total_score_per_hour * 100)
        comment.character_count_percentage = Math.trunc(comment.body.length / total_character_count * 100)
        if comment.score_hidden
            comment.estimated_interest = '---'
        else
            comment.estimated_interest = comment.score_per_hour_percentage + comment.character_count_percentage
        for reply in comment.replies
            set_interest_properties(total_score_per_hour, total_character_count, reply)
export get_post_fragment = (post_id, comment_id, context_level) ->
    api_op('GET',
        "comments/#{post_id}" +
        (if comment_id then "?comment=#{comment_id}" else '') +
        (if context_level then "&context=#{context_level}" else '')
    ).then ( [post_listing, replies_listing] ) ->
        post_fragment = {
            ...post_listing.data.children[0].data
            body: ''
            fragment_center: comment_id
            replies: process_replies replies_listing
            score_per_hour: 0
        }
        post_fragment.total_score_per_hour = subtree_score_per_hour post_fragment
        post_fragment.total_character_count = subtree_character_count post_fragment
        for comment in post_fragment.replies
            set_interest_properties(post_fragment.total_score_per_hour, post_fragment.total_character_count, comment)
        post_fragment

export get_feed_meta = (feed_config) ->
    if feed_config.name is ''
        new Promise (resolve, reject) -> resolve({ description_html: '' })
    else
        api_op('GET',
            "#{if feed_config.type is 'user' then 'user' else 'r'}/#{feed_config.name}/about"
        ).then (response) ->
            if response.data
                feed_meta = {
                    ...response.data
                    description_html: response.data.description_html[31...-20]
                }
            else
                { description_html: '' }