# Cargar las librerias necesarias 
library(tidyverse)
library(readxl)
library(ggplot2)
library(forecast)
library(ConvergenceClubs)

# Carga los datos desde el archivo CSV
data <- read.csv("C:/Users/marie/Downloads/dataset_provincias.csv")

# Verifica la estructura de los datos
str(data)

# Resumen estadístico de los datos
summary(data)

# Convertir la columna de fecha a formato fecha
data$fecha <- as.Date(data$fecha, format="%Y-%m-%d")

# Representar gráficamente las provincias
ggplot(data, aes(x=fecha, y=Unidades)) +
  geom_line() +
  facet_wrap(~Provincias)

# Filtrar y representar solo algunas provincias
data %>%
  filter(Provincias %in% c("Albacete", "Asturias")) %>%
  ggplot(aes(x=fecha, y=Unidades)) +
  geom_line() +
  facet_wrap(~Provincias)

# Calcular el máximo y las ventas normalizadas
data <- data %>%
  group_by(Provincias) %>%
  mutate(max= max(Unidades),
         value1 = Unidades/max)

# Gráfico de ventas normalizadas
ggplot(data, aes(x=fecha, y=value1)) +
  geom_line() +
  facet_wrap(~Provincias) +
  labs(x = "Fecha", y = "Unidades/ventas", title = "Ventas de cigarrillos por provincia ")

# Representación gráfica de provincias de más a menos ventas
data %>%
  summarise(media_udesxcapita = mean(value1)) %>%
  mutate(Provincias = fct_reorder(Provincias, media_udesxcapita)) %>%
  ggplot(aes(x=Provincias, y=media_udesxcapita, fill=Provincias)) +
  geom_col() +
  coord_flip() +
  labs(title = "Ranking de provincias por ventas per cápita", x = "", y = "Media de Unidades per cápita") +
  theme_minimal()

# Determinar si existe convergencia absoluta
# Definir las columnas a eliminar si están presentes en el dataframe
columns_to_remove <- c("X1", "Year", "Mes", "dia", "Población", "Euros", "precio", "UdesxCapita", "Provincias")

# Solo eliminar las columnas que existen
columns_to_remove <- columns_to_remove[columns_to_remove %in% names(data)]

# Procesar los datos eliminando solo las columnas que existen
data_processed <- data %>%
  select(-all_of(columns_to_remove)) %>%
  pivot_wider(names_from = fecha, values_from = Unidades, values_fill = list(Unidades = 0))

# En este punto, asegúrate de que 'Provincias' ya no está en el dataframe antes de convertirlo
# Si aún necesitas convertir 'Provincias' a numérico, debe hacerse antes de eliminar la columna

# Aplicar computeH si se han preparado los datos correctamente
if ("Provincias" %in% names(data_processed)) {
  data_processed$Provincias <- as.numeric(factor(data_processed$Provincias))
}

# Asegurar que todos los datos son numéricos y no hay NAs antes de proceder
data_processed <- drop_na(data_processed)

# Calcular H si es posible
if (ncol(data_processed) > 1) {
  H <- computeH(as.matrix(data_processed), quantity = "H")
  print(H)
} else {
  print("No hay suficientes columnas para calcular H.")
}

# Buscar clubes de convergencia usando la función findClubs
if (!is.null(H) && ncol(H) > 3) {
  clubsprov <- findClubs(H, dataCol = 2:ncol(H), unit_names = 1, refCol = ncol(H), 
                         time_trim = 1/3, cstar = 0, HACmethod = "FQSB")
  print(summary(clubsprov))
  
  
  # Visualización de los clubes de convergencia
  plot(clubsprov)
  plot(clubsprov, avgTP = FALSE, nrows = 3, ncols = 3, plot_args = list(type='l'))
  plot(clubsprov, clubs=NULL, avgTP = TRUE, legend=TRUE, plot_args = list(type='o'))
  
  # Combinar clubes si es necesario usando el método Phillips and Sul
  clubsprov2 <- mergeClubs(clubsprov, mergeMethod ='PS', threshold = -1.65, mergeDivergent = FALSE)
  print(summary(clubsprov2))
  plot(clubsprov2)
  plot(clubsprov2, avgTP = FALSE, nrows = 3, ncols = 3, plot_args = list(type='l'))
}

# Predicciones de series temporales para provincias seleccionadas
provincias_grup <- c("Madrid", "Girona", "Murcia", "Balears (Illes)", "Ciudad Real", "Cáceres", "Zamora")
for (i in provincias_grup) {
  df <- filter(data, Provincias == i)
  df <- df %>%
    mutate(Unidades = as.numeric(Unidades),
           fecha = as.Date(fecha, format="%Y-%m-%d"))
  df_ts <- ts(df$Unidades, frequency = 12, start = c(2005, 01))
  
  # División de datos para entrenamiento y prueba
  train <- window(df_ts, end = c(2017, 12))
  test <- window(df_ts, start = c(2018, 1))
  observed <- window(df_ts, start = c(2020, 1))
  
  # Modelado ARIMA
  modeloARIMA_mensual <- auto.arima(train)
  prediccionmensual <- forecast(modeloARIMA_mensual, h = 36)
  
  # Visualización de los datos de entrenamiento, test, pronóstico y post-COVID-19
  m <- autoplot(train, series = "Training Data") +
    autolayer(test, series = "Test Data") +
    autolayer(prediccionmensual, series = "Forecast") +
    autolayer(observed, series = "Post Covid-19 Sales") +
    labs(x = "Fecha", y = "Unidades", title = paste("Forecast de ventas para", i)) +
    scale_color_manual(values = c("#db8100", "#333333", "#7fb433", "#0098cd")) +
    theme_minimal()
  print(m)
}


