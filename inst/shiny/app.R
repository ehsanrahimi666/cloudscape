# Minimal scene explorer. Kept deliberately small: the analytical work belongs
# in the package, and this is only a viewer over it.
library(shiny)
library(cloudscape)

ui <- fluidPage(
  titlePanel("cloudscape scene explorer"),
  sidebarLayout(
    sidebarPanel(
      selectInput("sensor", "Sensor", choices = cl_sensors()$id,
                  selected = "sentinel-2-msi"),
      dateRangeInput("dates", "Period",
                     start = Sys.Date() - 365, end = Sys.Date()),
      numericInput("xmin", "West",  128.0), numericInput("ymin", "South", 35.5),
      numericInput("xmax", "East",  129.2), numericInput("ymax", "North", 36.2),
      sliderInput("maxcloud", "Max scene cloud (%)", 0, 100, 100),
      actionButton("go", "Search", class = "btn-primary"),
      hr(),
      selectInput("method", "Cloud method", choices = cl_methods()$method,
                  selected = "fmask"),
      sliderInput("thresh", "Probability threshold", 0, 1, 0.5, 0.05)
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Scenes", tableOutput("items")),
        tabPanel("Availability", tableOutput("avail")),
        tabPanel("Gaps", tableOutput("gaps"))
      )
    )
  )
)

server <- function(input, output, session) {
  items <- eventReactive(input$go, {
    cl_search(c(input$xmin, input$ymin, input$xmax, input$ymax),
              input$sensor, input$dates[1], input$dates[2],
              max_cloud = input$maxcloud, limit = 200)
  })
  obs <- reactive(cl_items_to_obs(items(), cl_grid(res = 25000)))
  output$items <- renderTable({
    d <- as.data.frame(items())
    d$datetime <- format(d$datetime, "%Y-%m-%d")
    head(d[, c("id", "datetime", "platform", "cloud_cover")], 30)
  })
  output$avail <- renderTable(summary(cl_clear_obs(obs(), by = "month")))
  output$gaps  <- renderTable(cl_stats_wide(cl_gaps(obs(), by = "all")))
}

shinyApp(ui, server)
