function New-HexSecret {
    $bytes = New-Object byte[] 16
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return -join ($bytes | ForEach-Object { $_.ToString("x2") })
}

$secret = New-HexSecret

Write-Host "Ваш секрет MTProto-прокси (сохраните его в .env, SECRET):"
Write-Host ""
Write-Host $secret
Write-Host ""
Write-Host "Секрет нужно скопировать в SECRET= в файле .env"
Write-Host ""

$ip = "IP_СЕРВЕРА"
Write-Host "Подключение: https://t.me/proxy?server=$ip&port=443&secret=$secret"
Write-Host "Подключение с фейковым TLS: https://t.me/proxy?server=$ip&port=443&secret=ee$secret"
