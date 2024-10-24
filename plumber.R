library(plumber)
library(ggplot2)
library(jsonlite)

dados = read.csv("dados_regressao.csv")
modelo = lm(y ~ x + grupo, data = dados)
options("plumber.port" = 7593)

#* @apiTitle API de Regressão Linear
#* @apiDescription Esta API possui funções relacionadas à Regressão Linear

################################################################################
#* Inserir um novo dado
#* @param x Variável numérica explicativa
#* @param y Variável numérica resposta
#* @param grupo Variável categórica explicativa
#* @post /insereDado
function(x, y, grupo) {
  nova_linha = data.frame(id = max(dados$id)+1, x, grupo, y, 
                          momento_registro = format(lubridate::now(), "%Y-%m-%dT%H:%M:%SZ")) 
  dados_atualizados = rbind(dados, nova_linha)
  readr::write_csv(dados_atualizados, file = "dados_regressao.csv")
  dados <<- read.csv("dados_regressao.csv")
}

################################################################################
#* Excluir um dado
#* @param id ID da linha a ser excluída
#* @post /excluiDado
function(id) {
  linha = which(dados$id == id)
  dados_novos = dados[-linha, ]
  readr::write_csv(dados_novos, file = "dados_regressao.csv")
  dados <<- read.csv("dados_regressao.csv")
}

################################################################################
#* Calcular os parâmetros da regressão
#* @serializer json
#* @get /parametros
function() {
  modelo <<- lm(y~x+grupo, data=dados)
  coeficientes = modelo$coefficients
  sigma = summary(modelo)$sigma
  nome = c(names(coeficientes), "sigma")
  valor = c(unname(coeficientes), sigma)
  df_final = data.frame(nome, valor)
  return(df_final)
}

################################################################################
#* Calcular a signficância dos coeficientes da regressão
#* @serializer json
#* @param sig Nível de significância dos coeficientes
#* @get /significancia
function(sig=0.05) {
  pvalor = unname(summary(modelo)$coefficients[,4])
  coeficientes = modelo$coefficients
  nome = names(coeficientes)
  df = data.frame(nome, pvalor)
  df$significativo = ifelse(pvalor < sig, "sim", "não")
  return(df)
}

################################################################################
#* Calcular os resíduos da regressão
#* @serializer json
#* @get /residuos
function() {
  residuos = summary(modelo)$residuals
  return(residuos)
}

################################################################################
#* Calcular os valores preditos para as observações do banco de dados
#* @serializer json
#* @get /preditos
function() {
  preditos = modelo$fitted.values
  return(preditos)
}

################################################################################
#* Calcular a predição para novos dados
#* @parser json
#* @serializer json
#* @get /predicao
function(req) {
  novos = req$body
  preditos = predict(modelo, novos)
  return(preditos)
}

################################################################################
#* Gráfico de regressão
#* @serializer png
#* @get /grafico
function() {
  grafico = dados %>%
    ggplot(aes(x=x, y=y, col=grupo))+
    geom_point()+
    geom_smooth(method = "lm", se=F)+
    labs(col = "Grupo")+
    theme_bw()
  print(grafico)
}

################################################################################
#* Gráficos de resíduos
#* @serializer png
#* @get /graficosResiduos
graficos_residuos = function(){
  residuos = summary(modelo)$residuals
  preditos = modelo$fitted.values
  df = data.frame(residuos, preditos)
  df_combinado = cbind(df, dados)
  
  graf1 = ggplot(data = df_combinado, aes(x = preditos, y = y)) +
    geom_point() +
    theme_bw() +
    labs(x = "Valores Preditos", y = "Valores observados")
  
  graf2 = ggplot(data = df_combinado, aes(sample = residuos)) +
    stat_qq(color = "black") +
    stat_qq_line(color = "blue") +
    theme_bw() +
    labs(x = "Quantis teóricos", y = "Quantis amostrais")
  
  graf3 = ggplot(data = df_combinado, aes(x = preditos, y = residuos)) +
    geom_hline(yintercept = 0, color = "blue") +
    geom_point() +
    theme_bw() +
    labs(x = "Valores Preditos", y = "Resíduos")
  
  graf4 = ggplot(data = df_combinado, aes(x = residuos)) +
    geom_histogram(aes(y = after_stat(density)), binwidth = 1, fill = "gray", color = "black") +
    geom_density(color = "blue", linewidth = 1) +
    theme_bw() +
    labs(y = "Densidade", x = "Resíduos")
  
  graf5 = ggplot(data = df_combinado, aes(x = seq_along(y), y = residuos)) +
    geom_hline(yintercept = 0, color = "blue") +
    geom_point() +
    theme_bw() +
    labs(x = "Índice da observação", y = "Resíduos")
  
  graf6 = ggplot(data = df_combinado, aes(y = residuos)) +
    geom_boxplot(fill = "gray", color = "black") +
    theme_minimal() +
    labs(y = "Resíduos") +
    theme(axis.text.x = element_blank())
  
  graficos = ggpubr::ggarrange(graf1, graf2, graf3, graf4, graf5, graf6,
                               ncol = 2, nrow = 3)
  
  print(graficos)
}
