#!/bin/bash

# Function to extract text from JSON
extract_json_text() {
  jq -r '.. | strings' "$1" 2>/dev/null | tr -d '\000' | iconv -f UTF-8 -t UTF-8//IGNORE
}

# Function to extract text from PDFs
extract_pdf_text() {
  pdftotext "$1" - | tr -d '\000' | iconv -f UTF-8 -t UTF-8//IGNORE
}

# Function to extract text from DOCX/DOC
extract_doc_text() {
  libreoffice --headless --convert-to txt:"Text (encoded)" "$1" --outdir "$(dirname "$1")" >/dev/null 2>&1
  txt_file="${1%.*}.txt"
  cat "$txt_file" | tr -d '\000' | iconv -f UTF-8 -t UTF-8//IGNORE
  rm -f "$txt_file"  # Cleanup
}

# Function to extract text from images (OCR)
extract_image_text() {
  tesseract "$1" stdout | tr -d '\000' | iconv -f UTF-8 -t UTF-8//IGNORE
}

# Function to extract raw text from any file
extract_text() {
  case "$1" in
    *.json) extract_json_text "$1" ;;
    *.pdf) extract_pdf_text "$1" ;;
    *.docx|*.doc) extract_doc_text "$1" ;;
    *.png|*.jpg|*.jpeg) extract_image_text "$1" ;;
    *) cat "$1" | tr -d '\000' | iconv -f UTF-8 -t UTF-8//IGNORE ;;
  esac
}

# Function to filter emails
filter_emails() {
  grep -Eo '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | grep -Ev '[%|*^#!]' | sort -u
}

# Function to filter domains (including from emails)
filter_domains() {
  grep -Eo '([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})' | grep -Ev '[%|*^#!]' | sort -u
}

# Function to filter URLs
filter_urls() {
  grep -Eo 'https?://[a-zA-Z0-9._%+-]+\.[a-zA-Z]{2,}(/[a-zA-Z0-9._%+-]*)*' | sort -u
}

# Function to filter IPv4 addresses
filter_ips() {
  grep -Eo '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | grep -Ev '[^0-9.]' | awk -F '.' '$1<=255 && $2<=255 && $3<=255 && $4<=255' | sort -u
}

# Function to display usage
usage() {
  echo "Usage: $0 -f <input_file> --email | --domain | --url | --ip [-o <output_file>]"
  exit 1
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)
      input_file="$2"
      shift 2
      ;;
    --email)
      filter_type="email"
      shift
      ;;
    --domain)
      filter_type="domain"
      shift
      ;;
    --url)
      filter_type="url"
      shift
      ;;
    --ip)
      filter_type="ip"
      shift
      ;;
    -o)
      output_file="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

# Check if input file and filter type are provided
if [[ -z "$input_file" || -z "$filter_type" ]]; then
  usage
fi

# Extract text from the file
input_text=$(extract_text "$input_file")

# Apply the selected filter
case "$filter_type" in
  email)
    result=$(echo "$input_text" | filter_emails)
    ;;
  domain)
    result=$(echo "$input_text" | filter_domains)
    ;;
  url)
    result=$(echo "$input_text" | filter_urls)
    ;;
  ip)
    result=$(echo "$input_text" | filter_ips)
    ;;
esac

# Output result to file or print to terminal
if [[ -n "$output_file" ]]; then
  echo "$result" > "$output_file"
  echo -e "✅ Filtered $filter_type data has been saved to $output_file"
else
  echo "$result"
fi
