class TabHandleView extends KDView
  setDomElement:()->
    @domElement = $ "<b>Terminal</b>
      <span class='kdcustomhtml terminal icon'></span>"


class Shell12345 extends KDViewController
  
  nextScreenDiff:(data, messageNum)->
    {_lastMessageProcessed, _orderedMessages} = @
    _orderedMessages[messageNum] = data
    if messageNum is _lastMessageProcessed
      doThese = []
      i = _lastMessageProcessed
      for diff in (item while (item = _orderedMessages[i++])?)
        @getView().updateScreen(diff)
      @_lastMessageProcessed = i-1
  
  resetMessageCounter:->
    console.log 'message counter is reset.'
    @_lastMessageProcessed = 0
    @_orderedMessages = []
  
  generateTerminalOptions : ()->
    view = @getView()
    options = view.getSize()
    options.callbacks = 
      data : (data, messageNum) => 
        @nextScreenDiff data, messageNum
        
        # console.log data
      error : (error) =>
        @getView().disableInput()
        msg = "connection closed"
        if error.msg then msg += ",#{error.msg}"
        @setNotification msg
      ping : () =>
        try
          @terminal.ping()
        catch e
          console.log "terminal ping error: #{e}"
        
    options.callbacks.newSession = (totalViews)=>
      console.log "new session"
      notification = new KDNotificationView
        title   : "Terminal has #{totalViews} views"
        duration: 1500
    return options

  constructor:()->
    super
    @account = KD.whoami()
    # @getKiteIds kiteName:"terminaljs",->
    @_terminalId = null
    @setView shellView = new ShellView
    @resetMessageCounter()
    shellView.registerListener KDEventTypes:'ViewClosed', listener:@, callback:@closeView
    resetRegexp = /reset\:.*?/
    shellView.registerListener KDEventTypes:'AdvancedSettingsFunction', listener:@, callback:(pubInst, {functionName})=>
      switch functionName
        when 'clear'
          @send "clear\n"
        when 'closeOtherSessions'
          try
            @terminal.closeOtherSessions()
          catch e
            console.log "terminal:closeOtherSessions error : #{e}"
        else
          if resetRegexp.test functionName
            clientType = functionName.substr 6
            if not clientType
              clientType = shellView.clientType
            @resetTerminalSession clientType

  setNotification:(msg)->
    if @notification?
      @notification.destroy()
      delete @notification
    if msg?
      @notification = new KDNotificationView
        title   : "#{msg}"
        duration: 0

  resetTerminalSession :(type)->
    @setNotification "restarting terminal"
    view = @getView()
    view.reset type
    try
      @terminal.kill()
      @resetMessageCounter()
    catch e
      console.log "terminal kill error : #{e}"
    options = @generateTerminalOptions()
    options.type = type ? view.clientType
    @account.tellKite 
      kiteName :"terminaljs"
      toDo     :"create"
      withArgs : options
    ,(error,terminal)=>
      if error
        @setNotification "Failed to start terminal : #{error}"
      else
        @setNotification()
        @terminal = terminal
        @welcomeUser yes
      
  initApplication:(options,callback)=>
    @applyStyleSheet ()=>
      callback()
      @propagateEvent
        KDEventType : 'ApplicationInitialized', globalEvent : yes
  
  bringToFront:()=>
    @propagateEvent (KDEventType : 'ApplicationWantsToBeShown', globalEvent : yes),
      options :
        name              : 'Terminal'
        type              : 'application'
        tabHandleView     : new TabHandleView()
        hiddenHandle      : no
        applicationType   : 'Shell.kdapplication'
      data : @getView()
      
    appManager.addOpenTab @getView(), 'Shell.kdapplication'
    @getView().input.setFocus()
    
  initAndBringToFront:(options,callback)=>
    @initApplication options, =>
      @bringToFront()
      callback()
  
  closeView:(view)->
    appManager.removeOpenTab @getView()
    view.parent.removeSubView view
    @propagateEvent (KDEventType : 'ApplicationWantsToClose', globalEvent : yes), data : view
    view.destroy()
    @setNotification()
    try
      @terminal.kill()
    catch e
      console.log "terminal::close error #{e}"
    @resetMessageCounter()

  applyStyleSheet:(callback)->
    callback?()
    # $.ajax
    #   dataType:'text'
    #   url:"#{KD.staticFilesBaseUrl}/js/KDApplications/Shell.kdapplication/app.css?#{KD.version}"
    #   success: (css)->
    #     $("<style type='text/css'>#{css}</style>").appendTo("head");
    #     callback?()

  getKiteIds : (options,callback)->
    @account.fetchKiteIds {kiteName:"terminaljs"},(err,kiteIds)->
      unless err
        @kiteIds = kiteIds
        callback? null,kiteIds
      else
        callback? err

  initiateTerminal : (callback)->
    view = @getView()
    options = @generateTerminalOptions()
    options.type = view.clientType
    # @pickAResponsiveKite {},(err,kiteId)=>
    #   console.log "whatup",err,kiteId 
    console.log 'initial terminal is called'
    KD.singletons.kiteController.run
      kiteName  : "terminaljs"
      # kiteId    : kiteId
      toDo      : "create"
      withArgs  : options
    , (error, terminal) =>
      if error
        @setNotification "Failed to start terminal, please close the tab and try again."
        console.log error
      else
        @terminal = terminal
        @welcomeUser terminal.isNew
        callback? terminal.totalSessions

      
  loadView:(mainView)->
    @initiateTerminal (totalSessions)=>
      mainView.registerListener
        KDEventTypes : "resize"
        listener     : @
        callback     : @resizeTerminal
      mainView.input.on "data",(cmd)=>
        @send cmd

  welcomeUser:(isTerminalNew)->
    if isTerminalNew
      username = KD.getSingleton('mainController').getVisitor().currentDelegate.profile.nickname
      welcomeText = "cowsay mooOOooOOoo what up #{username}! welcome to your terminal... check my w"
      @send "#{welcomeText}\n"

  resizeTerminal:()->
    options     = @getView().getSize()
    try
      @terminal.resize options.rows, options.cols
    catch e
      console.log "terminal::resize error #{e}"

  send: (command) ->
    # console.log "sending:"+command
    try
      @terminal.write command
    catch e
      console.log "terminal::write error : #{e}"


# define ()->
#   application = new AppController()
#   {initApplication, initAndBringToFront, bringToFront, openFile} = application
#   {initApplication, initAndBringToFront, bringToFront, openFile}
#   #the reason I'm returning the whole instance right now is because propagateEvent includes the whole thing anyway. switch to emit/on and we can change this...
#   return application

