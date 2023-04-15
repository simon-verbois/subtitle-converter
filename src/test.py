import pytesseract
import subprocess

# Chemin du fichier de sous-titres PGS (.sup)
pgs_file_path = 'chemin/vers/fichier.sup'

# Chemin du fichier de sous-titres SRT (.srt)
srt_file_path = 'chemin/vers/fichier.srt'

# Utilisation de Subprocess pour convertir le fichier PGS en PNG
subprocess.call(['ffmpeg', '-i', pgs_file_path, '-c:v', 'png', '-f', 'image2pipe', '-'], stdout=open('/dev/null', 'w'))

# Utilisation de Pytesseract pour lire le texte des images PNG
text = pytesseract.image_to_string('/dev/stdin')

# Séparation du texte en lignes et en temps de début/fin
lines = text.splitlines()
times = [lines[i] + ' --> ' + lines[i+1] for i in range(0, len(lines), 2)]

# Écriture du fichier SRT
with open(srt_file_path, 'w') as srt_file:
    for i, line in enumerate(lines):
        # Ignorer les temps de début/fin
        if i % 2 == 0:
            continue
        srt_file.write(str(i//2+1) + '\n')
        srt_file.write(times[i//2] + '\n')
        srt_file.write(line + '\n\n')
