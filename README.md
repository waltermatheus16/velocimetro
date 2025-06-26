# Velocímetro com Mapa

Um aplicativo Flutter que combina velocímetro em tempo real com funcionalidades de mapa e busca de endereços.

## Funcionalidades

- **Velocímetro em tempo real**: Monitora velocidade, distância, velocidade média e tempo
- **Mapa interativo**: Visualização em tempo real da posição e rota percorrida
- **Busca de endereços**: Barra de busca para encontrar locais no mapa
- **Rastreamento de rota**: Desenha a rota percorrida no mapa
- **Atualização em tempo real**: Posição atualizada conforme o dispositivo se move

## Configuração

### 1. Instalar dependências

```bash
flutter pub get
```

### 2. Configurar Google Maps API

1. Acesse o [Google Cloud Console](https://console.cloud.google.com/)
2. Crie um novo projeto ou selecione um existente
3. Ative as seguintes APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Geocoding API
4. Crie uma chave de API
5. Substitua `YOUR_GOOGLE_MAPS_API_KEY` no arquivo `android/app/src/main/AndroidManifest.xml` pela sua chave real

### 3. Configurar ícone personalizado

1. Substitua o arquivo `assets/app_icon.png` pelo seu ícone personalizado
2. Execute o comando para gerar os ícones:

```bash
flutter pub run flutter_launcher_icons:main
```

### 4. Permissões

O aplicativo já está configurado com as permissões necessárias:
- Localização precisa
- Localização aproximada
- Localização em segundo plano
- Serviço em primeiro plano
- Manter tela ligada

## Como usar

1. **Iniciar rastreamento**: Toque no botão "Iniciar" para começar a monitorar velocidade e posição
2. **Buscar endereço**: Use a barra de busca no topo para encontrar locais
3. **Visualizar rota**: A rota percorrida é desenhada automaticamente no mapa
4. **Parar rastreamento**: Toque em "Parar" para interromper o monitoramento
5. **Reset**: Use o botão "Reset" para limpar todos os dados

## Estrutura do projeto

- `lib/main.dart`: Arquivo principal com toda a lógica do aplicativo
- `assets/`: Pasta para recursos como ícones
- `android/`: Configurações específicas para Android
- `ios/`: Configurações específicas para iOS

## Dependências principais

- `google_maps_flutter`: Para exibição do mapa
- `geolocator`: Para obtenção da localização
- `geocoding`: Para busca de endereços
- `wakelock_plus`: Para manter a tela ligada
- `intl`: Para formatação de números

## Notas importantes

- O aplicativo requer permissão de localização para funcionar
- Para melhor precisão, use em dispositivos com GPS
- A busca de endereços requer conexão com a internet
- O rastreamento em segundo plano pode consumir bateria

## Desenvolvimento

Para executar o projeto:

```bash
flutter run
```

Para gerar APK:

```bash
flutter build apk
```
