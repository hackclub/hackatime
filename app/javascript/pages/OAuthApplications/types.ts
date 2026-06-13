type OAuthApplicationSummary = {
  id: number;
  name: string;
  verified: boolean;
  confidential: boolean;
  scopes: string[];
  redirect_uris: string[];
};

export type OAuthApplicationsIndexProps = {
  page_title: string;
  applications: OAuthApplicationSummary[];
};

type OAuthScopeOption = {
  value: string;
  description: string;
  default: boolean;
};

type OAuthApplicationFormApplication = {
  id: number | null;
  persisted: boolean;
  name: string;
  redirect_uri: string;
  confidential: boolean;
  redirect_to_hca_login: boolean;
  verified: boolean;
  selected_scopes: string[];
};

type OAuthApplicationFormErrors = {
  full_messages: string[];
  name: string[];
  redirect_uri: string[];
  scopes: string[];
  confidential: string[];
  redirect_to_hca_login: boolean;
};

export type OAuthApplicationFormProps = {
  page_title: string;
  heading: string;
  subheading: string;
  form_mode: "new" | "edit";
  form_method: "post" | "patch";
  labels: {
    submit: string;
    cancel: string;
  };
  help_text: {
    redirect_uri: string;
    blank_redirect_uri: string;
    confidential: string;
  };
  allow_blank_redirect_uri: boolean;
  application: OAuthApplicationFormApplication;
  scope_options: OAuthScopeOption[];
  errors: OAuthApplicationFormErrors;
};

type OAuthApplicationShowApplication = {
  id: number;
  name: string;
  uid: string;
  verified: boolean;
  confidential: boolean;
  redirect_to_hca_login: boolean;
  scopes: string[];
  redirect_uris: string[];
  can_toggle_verified: boolean;
};

export type OAuthApplicationShowProps = {
  page_title: string;
  heading: string;
  subheading: string;
  application: OAuthApplicationShowApplication;
  secret: {
    value: string | null;
    hashed: boolean;
    just_rotated: boolean;
  };
  labels: {
    application_id: string;
    secret: string;
    secret_hashed: string;
    scopes: string;
    confidential: string;
    callback_urls: string;
    actions: string;
    not_defined: string;
  };
  confirmations: {
    rotate_secret: string;
  };
};
