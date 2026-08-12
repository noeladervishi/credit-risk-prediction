library(shiny)
library(bslib)
library(plotly)
library(dplyr)
library(targets)

for (f in list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE)) source(f)

xgb_model  <- tar_read(xgb_model)
test_df    <- tar_read(test_df)
shap_vals  <- tar_read(shap_values)
mc_pd      <- tar_read(mc_pd)
mc_ead     <- tar_read(mc_ead)
mc_lgd     <- tar_read(mc_lgd)

ui <- page_sidebar(
  title = "Credit Risk Monitor — PD, Explainability & Portfolio Stress",
  theme = bs_theme(bootswatch = "flatly"),
  header = tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
    tags$script(src = "theme-toggle.js"),
    tags$div(
      class = "theme-toggle-wrap",
      style = "position: absolute; top: 0.6rem; right: 1rem; z-index: 1000;",
      tags$span("\u2600\uFE0F"),
      tags$label(
        class = "theme-toggle",
        tags$input(type = "checkbox", id = "theme_switch"),
        tags$span(class = "slider")),
      tags$span("\U0001F319"))),

  sidebar = sidebar(
    width = 350,
    h5("Borrower Explanation"),
    selectInput("borrower_idx", "Select borrower (test set row)",
                choices = seq_len(nrow(test_df)), selected = 1),
    hr(),
    h5("Portfolio Stress Scenario"),
    sliderInput("stress_shift", "Systemic shock (macro factor shift)",
                min = -4, max = 2, value = 0, step = 0.25,
                animate = animationOptions(interval = 800)),
    helpText("Negative values simulate a recession-style downturn ",
             "(correlated defaults rise). 0 = baseline conditions."),
    sliderInput("rho", "Asset (default) correlation \u03C1",
                min = 0.02, max = 0.5, value = 0.15, step = 0.01),
    numericInput("n_sim", "Number of simulations", value = 5000,
                 min = 1000, max = 20000, step = 1000)),

  layout_columns(
    col_widths = c(6, 6),
    card(
      card_header("Borrower: Predicted PD & SHAP Reason Codes"),
      textOutput("borrower_pd"),
      plotlyOutput("shap_plot", height = "350px")),
    card(
      card_header("Simulated Portfolio Loss Distribution"),
      plotlyOutput("loss_plot", height = "350px"))),

  card(
    card_header("Risk Metrics Under Current Scenario"),
    tableOutput("risk_table")))

server <- function(input, output, session) {
  output$borrower_pd <- renderText({
    idx <- as.integer(input$borrower_idx)
    pd_pred <- predict_xgboost(xgb_model, test_df[idx, , drop = FALSE])
    paste0("Predicted probability of default: ", round(pd_pred * 100, 2), "%")})
  output$shap_plot <- renderPlotly({
    idx <- as.integer(input$borrower_idx)
    explanation <- explain_borrower(shap_vals, idx, top_n = 8)
    plot_ly(
      explanation,
      x = ~shap_value, y = ~reorder(feature, shap_value),
      type = "bar", orientation = "h",
      color = ~direction,
      colors = c("Increases risk" = "#E74C3C", "Decreases risk" = "#2ECC71")
    ) %>%
      layout(xaxis = list(title = "SHAP contribution"), yaxis = list(title = ""))})

  scenario_result <- reactive({
    defaults <- simulate_correlated_defaults(
      pd = pmin(pmax(mc_pd, 1e-4), 1 - 1e-4),
      rho = input$rho,
      n_sim = input$n_sim,
      stress_shift = input$stress_shift,
      seed = 42)
    losses <- simulate_portfolio_loss(defaults, mc_ead, mc_lgd)
    list(losses = losses, summary = risk_summary(losses))})

  output$loss_plot <- renderPlotly({
    plot_ly(x = scenario_result()$losses, type = "histogram", nbinsx = 60) %>%
      layout(
        xaxis = list(title = "Simulated Portfolio Loss ($)"),
        yaxis = list(title = "Frequency"),
        title = paste0("Shock: ", input$stress_shift, "  |  \u03C1: ", input$rho))})

  output$risk_table <- renderTable({
    scenario_result()$summary %>%
      mutate(
        confidence = scales::percent(confidence),
        expected_loss = fmt_currency(expected_loss),
        var = fmt_currency(var),
        cvar = fmt_currency(cvar)
      ) %>%
      rename(
        `Confidence` = confidence,
        `Expected Loss` = expected_loss,
        `VaR` = var,
        `CVaR (Expected Shortfall)` = cvar)})}

shinyApp(ui, server)