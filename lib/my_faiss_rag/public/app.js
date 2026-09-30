const messages = document.getElementById('messages');
const form = document.getElementById('chat');
const input = document.getElementById('question');
const button = form.querySelector('button');
const welcome = document.getElementById('welcome');

function addMessage(role) {
  welcome.hidden = true;

  const message = document.createElement('div');
  message.className = `message ${role}`;

  const content = document.createElement('div');
  content.className = 'content';

  if (role === 'assistant') {
    const avatar = document.createElement('div');
    avatar.className = 'avatar';
    avatar.textContent = 'RH';
    message.append(avatar);
  }

  message.append(content);
  messages.append(message);

  return content;
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();

  const question = input.value.trim();
  if (!question) return;

  input.value = '';
  button.disabled = true;
  addMessage('user').textContent = question;

  const answer = addMessage('assistant');
  answer.innerHTML = '<span class="spinner">Buscando...</span>';
  answer.scrollIntoView({ block: 'end' });

  try {
    const response = await fetch('/ask', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question })
    });
    const data = await response.json();

    if (!response.ok) throw new Error(data.error);
    answer.textContent = data.answer;
  } catch (error) {
    answer.classList.add('error');
    answer.textContent = error.message || 'Erro de conexão com o servidor.';
  } finally {
    button.disabled = false;
    input.focus();
    answer.scrollIntoView({ block: 'end' });
  }
});

document.querySelectorAll('.suggestion').forEach((suggestion) => {
  suggestion.addEventListener('click', () => {
    input.value = suggestion.dataset.question;
    form.requestSubmit();
  });
});
