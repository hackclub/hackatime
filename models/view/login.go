package view

type LoginViewModel struct {
	SharedViewModel
	TotalUsers   int
	AllowSignup  bool
	CaptchaId    string
	InviteCode   string
	SlackEnabled bool
}

type SetPasswordViewModel struct {
	LoginViewModel
	Token string
}

func (s *LoginViewModel) WithSuccess(m string) *LoginViewModel {
	s.SetSuccess(m)
	return s
}

func (s *LoginViewModel) WithError(m string) *LoginViewModel {
	s.SetError(m)
	return s
}
