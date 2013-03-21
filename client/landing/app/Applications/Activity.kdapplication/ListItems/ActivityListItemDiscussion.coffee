class DiscussionActivityItemView extends ActivityItemChild

  constructor:(options, data)->

    unless data.opinionCount?
      # log "This is legacy data. Updating Counts."
      data.opinionCount = data.repliesCount or 0
      data.repliesCount = 0

    options = $.extend
      cssClass    : "activity-item discussion"
      tooltip     :
        title     : "Discussion"
        offset    :
          top     : 3
          left    : -5
        selector  : "span.type-icon"
    ,options

    super options,data

    @actionLinks = new DiscussionActivityActionsView
      delegate : @commentBox.opinionList
      cssClass : "reply-header"
    , data

    data.on 'ReplyIsAdded', (reply)=>
      if data.bongo_.constructorName is "JDiscussion"
        @opinionBox.opinionList.emit "NewOpinionHasArrived"

    @opinionBox = new DiscussionActivityOpinionView
      cssClass    : "activity-opinion-list comment-container"
    , data

    # When an opinion gets deleted, then the removeReply method of JDiscussion
    # will emit this event. This is a workaround for the OpinionIsDeleted
    # event not being caught for opinions that are loaded to the client data
    # structure after the snapshot is loaded

    data.on "ReplyIsRemoved",(replyId)=>

      # this will remove the item from the list if the data doesn't
      # contain it anymore, but the list does. the next snapshot refresh
      # will be okay
      # This is needed, because the "OpinionIsDeleted" event isn't available
      # for newly added JOpinions, for some reason. --arvid

      for item,i in @opinionBox.opinionList.items
        if item?.getData()._id is replyId
          item.hide()
          item.destroy()

    @scrollAreaOverlay = new KDView
      cssClass : "enable-scroll-overlay"
      partial  : ""

    @timeAgoView = new KDTimeAgoView {}, @getData().meta.createdAt

    # @scrollAreaHint = new KDView
    #   cssClass : "enable-scroll-hint"
    #   partial : "Don't move your mouse to scroll"

    # @scrollAreaList = new KDButtonGroupView
    #   buttons:
    #     "Allow Scrolling here":
    #       # cssClass : ""
    #       callback:=>
    #         @$("div.discussion-body-container").addClass "scrollable-y"
    #         @$("div.discussion-body-container").removeClass "no-scroll"

    #         @scrollAreaOverlay.hide()
    #     "View the full Discussion":
    #       callback:=>
    #         KD.getSingleton("appManager").tell "Activity", "createContentDisplay", @getData()

    # @scrollAreaOverlay.addSubView @scrollAreaList

  viewAppended:()->
    return if @getData().constructor is KD.remote.api.CDiscussionActivity
    super()
    @setTemplate @pistachio()
    @template.update()

    @highlightCode()
    @prepareExternalLinks()
    @prepareScrollOverlay()

  highlightCode:->
    @$("div.discussion-body-container span.data pre").each (i,element)=>
      hljs.highlightBlock element

  prepareExternalLinks:->
    @$('p.body a[href^=http]').attr "target", "_blank"

  prepareScrollOverlay:->
    @utils.defer =>

      body = @$("div.activity-content-container.discussion")
      if body.height() < parseInt body.css("max-height"), 10
        @scrollAreaOverlay.hide()
      else
        body.addClass "scrolling-down"
        cachedHeight = body.height()

        body.scroll =>

          percentageTop    = 100*body.scrollTop()/body[0].scrollHeight
          percentageBottom = 100*(cachedHeight+body.scrollTop())/body[0].scrollHeight

          distanceTop      = body.scrollTop()
          distanceBottom   = body[0].scrollHeight-(cachedHeight+body.scrollTop())

          triggerValues    =
            top            :
              percentage   : 0.5
              distance     : 15
            bottom         :
              percentage   : 99.5
              distance     : 15

          if percentageTop < triggerValues.top.percentage or\
             distanceTop < triggerValues.top.distance

            body.addClass "scrolling-down"
            body.removeClass "scrolling-both"
            body.removeClass "scrolling-up"

          if percentageBottom > triggerValues.bottom.percentage or\
             distanceBottom < triggerValues.bottom.distance

            body.addClass "scrolling-up"
            body.removeClass "scrolling-both"
            body.removeClass "scrolling-down"

          if percentageTop >= triggerValues.top.percentage and\
             percentageBottom <= triggerValues.bottom.percentage and\
             distanceBottom > triggerValues.bottom.distance and\
             distanceTop > triggerValues.top.distance

            body.addClass "scrolling-both"
            body.removeClass "scrolling-up"
            body.removeClass "scrolling-down"

    @$("div.activity-content-container").hover (event)=>

      @transitionStart = setTimeout =>
        @scrollAreaOverlay.$().css top:"100%"
      , 500
      unless @scrollAreaOverlay.$().hasClass "hidden"
        @checkForCompleteAnimationInterval = setInterval =>
          if (parseInt(@scrollAreaOverlay.$().css("top"),10)+@$("div.discussion").scrollTop()) >= @scrollAreaOverlay.$().height()
            @scrollAreaOverlay.hide()
            @$("div.discussion").addClass "scrollable-y scroll-highlight"
            @$("div.discussion").removeClass "no-scroll"
            clearInterval @checkForCompleteAnimationInterval if @checkForCompleteAnimationInterval?
        ,50
    , (event)=>
      unless parseInt(@scrollAreaOverlay.$().css("top"),10) >= @scrollAreaOverlay.$().height()
        clearTimeout @transitionStart if @transitionStart?
        clearInterval @checkForCompleteAnimationInterval if @checkForCompleteAnimationInterval?
        @scrollAreaOverlay.$().css top:"0px"
        @$("div.discussion").removeClass "scrollable-y scroll-highlight"
        @$("div.discussion").addClass "no-scroll"
        @scrollAreaOverlay.show()

  render:->
    super()
    @highlightCode()
    @prepareExternalLinks()
    @prepareScrollOverlay()

  click:(event)->
    if $(event.target).is("[data-paths~=title]")
      # if not $(event.target).is("a.action-link, a.count, .like-view")
        KD.getSingleton('router').handleRoute "/Activity/#{@getData().slug}", state:@getData()

  applyTextExpansions:(str = "")->
    str = @utils.expandUsernames str

    if str.length > 500
      visiblePart = str.substr 0, 500
      # this breaks the markdown sanitizer
      # morePart = "<span class='more'><a href='#' class='more-link'>show more...</a>#{str.substr 501}<a href='#' class='less-link'>...show less</a></span>"
      str = visiblePart  + " ..." #+ morePart

    return str

  pistachio:->
    """
    <div class="activity-discussion-container">
      <span class="avatar">{{> @avatar}}</span>
      <div class='activity-item-right-col'>
        {{> @settingsButton}}
        <h3 class='comment-title'>{{@applyTextExpansions #(title)}}</h3>
        <div class="activity-content-container discussion">
          <p class="body no-scroll has-markdown force-small-markdown">
            {{@utils.expandUsernames @utils.applyMarkdown #(body)}}
          </p>
          {{> @scrollAreaOverlay}}
        </div>
        <footer class='clearfix'>
          <div class='type-and-time'>
            <span class='type-icon'></span> by {{> @author}}
            {{> @timeAgoView}}
            {{> @tags}}
          </div>
          {{> @actionLinks}}
        </footer>
        {{> @opinionBox}}
      </div>
    </div>
    """

