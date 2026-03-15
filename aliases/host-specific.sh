# Docker Specific aliases 
if [ "$HOSTNAME" = "sol" ]; then
  alias rustscan='docker run -it --rm --name rustscan rustscan/rustscan:2.1.1'
  alias gemini="npx @google/gemini-cli"
fi

