# Data dashboard for Metro21 Fire Risk Analysis Project
# Created for: Pittsburgh Bureau of Fire
# Authors: Qianyi Hu, Michael Madaio, Geoffrey Arnold
# Latest update: February 20, 2018


# The server side of the dashboard

source("global.R", local = FALSE)

shinyServer(function(input, output, session) {
  # Bookmark Event
  observeEvent(input$bookmark, {
    bookmarks <- isolate(reactiveValuesToList(input))
    if (is.null(inputs)) {
      data <- bookmarks
    } else {
      data <- bookmarks
      for (i in names(inputs[!grepl("^_", names(inputs))])) {
        data[i] <- ifelse(is.null(bookmarks[i]), inputs[i], bookmarks[i])
        names(data[i]) <- i
      }
    }
    # print(bookmarks)
    addUpdateDoc(bookmark_id, data, conn)
    showNotification("Your bookmarks have been saved successfully", type = "message")
  })
  model <- loadModel

  model$Score <- ceiling(model$RiskScore*10)
  
  # get data subset
  data <- reactive({
    # default option: select all
   
    print("Filtering Fire Risk Scores")

    d <- subset(model, subset = (Score <= input$range[2] & Score >= input$range[1]))

    # filter by property type (STATEDESC)
    if (!("All Classification Types" %in% input$property)){
      d <- subset(d, subset=(state_desc %in% input$property))
    }
    
    # filter by usage type (USEDESC)
    if (!("All Usage Types" %in% input$use)) {
      d <- subset(d, subset=(use_desc %in% input$use))
    }
    
    # filter by neighborhood (NEIGHDESC)
    if (!("All Neighborhoods" %in% input$nbhood)) {
      d <- subset(d, subset=(geo_name_nhood %in% input$nbhood))
    }
    # filter by fire district
    if (!("All Fire Districts" %in% input$fire_dst)){
      d <- subset(d, subset=(Pgh_FireDistrict %in% input$fire_dst)) 
    }
    d
  })
  
  # visualization plot
  output$distPlot <- renderPlotly({
    
    
    if (input$xvar == "Property Classification") {
      x_axis <- "state_desc"
    } else if (input$xvar == "Property Usage Type") {
      x_axis <- "use_desc"
    } else if (input$xvar == "Neighborhood") {
      x_axis <- "geo_name_nhood"
    }
    
    if (input$yvar == "Fire Risk Scores") {
      if (input$xvar == "Fire District") {
        x_axis <- "Pgh_FireDistrict"
      } 
      
    } 
    
    y_axis <- input$yvar
    
    
    
    
    ## Create visualization ##
    
    if (y_axis == "Fire Risk Scores"){
      print("displaying Fire risk")
      
      
      # consider average risk score by x axis
      if (nlevels(data()[[x_axis]]) <= 15){
        plot <- ggplot(data = data()[!is.na(data()[[x_axis]]),],aes(x=data()[!is.na(data()[[x_axis]]),][[x_axis]],y=Score)) + 
          stat_summary(fun.y = "mean",geom = "bar",width=0.8,fill="steelblue") + 
          theme(plot.title = element_text(size = 18, face = "bold"),text = element_text(size=12)) +
          ggtitle("Average Risk Score") + ylim(0,10) + 
          xlab(x_axis) +
          ylab("Risk Score")
        
      }else{
        data_selected <- data()[!is.na(data()[[x_axis]]),]
        
        ag_score <- aggregate(data_selected[["Score"]] ~ data_selected[[x_axis]], data_selected, mean)
        ag_label <- as.vector(unlist(ag_score[order(ag_score[2]),][1]))
        print(length(ag_label))
        # h = 550 + 10 * length(ag_label)
        plot <- ggplot(data = data_selected, aes(x=data_selected[[x_axis]],y=Score)) + 
          stat_summary(fun.y = "mean",geom = "bar",width=0.8,fill="steelblue") + 
          coord_flip() + scale_x_discrete(limits=ag_label,labels=ag_label) +
          ggtitle("Average Risk Score") + ylim(0,10) + 
          theme(plot.title = element_text(size = 18, face = "bold"),text = element_text(size=12)) +
          xlab(x_axis) +
          ylab("Risk Score")
      }
      
    }
    plot 
  })
  output$table <- DT::renderDataTable(data(), options = list(scrollX = TRUE))
 
  # download table
  output$downloadTable <- downloadHandler(
    filename = "table.csv",
    content = function(file) {
      write.csv(as.data.frame(data()), file)
    }
  )
  
  # print total number of records selected (for reference)
  output$n_records <- renderText({
    nrow(data())
  })

  

})
