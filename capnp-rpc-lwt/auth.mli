(** Vat-level authentication and encryption.

    Unless your network provides a secure mechanism for establishing connections
    to other vats, where you can be sure of the identity of the other party,
    you'll probably want to enable cryptographic security.

    Each vat (application instance) should generate a secret key when it is first
    deployed. For servers at least, this key must be saved to disk so that the
    server retains its identity over re-starts. Otherwise, clients will think it
    is an imposter and refuse to connect.

    Clients that do not accept incoming connections, nor create SturdyRefs, can
    get away with creating a new key each time. However, it might be quicker
    to save and reload the key anyway. *)

type hash = [`SHA256]
(** Supported hashes. *)

module Digest : sig
  type t
  (** The digest of a public key, used to recognise a vat.
      This appears in URIs as e.g. 'capnp://sha256:1234@host/'. *)

  val insecure : t
  (** A special value indicating no authentication should be performed. *)

  val from_uri : Uri.t -> (t, [> `Msg of string]) result
  (** [from_uri t] is the parsed digest information in [t]. *)

  val add_to_uri : t -> Uri.t -> Uri.t
  (** [add_to_uri t uri] is [uri] with the [user] and [password] fields set
      to the correct values for [t]. Note that although we use the "password" field,
      this is not secret. *)

  val authenticator : t -> X509_lwt.authenticator option
  (** [authenticator t] is an authenticator that checks that the peer's public key
      matches [t]. Returns [None] if [t] is [insecure].
      Note: it currently also requires the DN field to be "capnp". *)

  val equal : t -> t -> bool

  val pp : t Fmt.t
end

module Secret_key : sig
  type t
  (** A vat's [secret_key] allows it to prove its identity to other vats. *)

  val generate : unit -> t
  (** [generate ()] is a fresh secret key.
      You must call [Nocrypto_entropy_lwt.initialize] before using this (it will give an
      error if you forget). *)

  val digest : ?hash:hash -> t -> Digest.t
  (** [digest ~hash t] is the digest of [t]'s public key, using [hash]. *)

  val of_pem_data : string -> t
  (** [of_pem_data data] parses [data] as a PEM-encoded private key. *)

  val to_pem_data : t -> string
  (** [to_pem_data t] returns [t] as a PEM-encoded private key. *)

  val certificates : t -> Tls.Config.own_cert
  (** [certificates t] is the TLS certificate chain to use for a vat with secret key [t]. *)

  val pp_fingerprint : hash -> t Fmt.t
  (** [pp_fingerprint hash] formats the hash of [t]'s public key. *)

  val equal : t -> t -> bool
end

module Tls_wrapper (Underlying : Mirage_flow_lwt.S) : sig
  (** Make an [Endpoint] from an [Underlying.flow], using TLS if appropriate. *)

  val connect_as_server :
    switch:Lwt_switch.t -> Underlying.flow -> Secret_key.t option ->
    (Endpoint.t, [> `Msg of string]) result Lwt.t

  val connect_as_client :
    switch:Lwt_switch.t -> Underlying.flow -> Secret_key.t Lazy.t -> Digest.t ->
    (Endpoint.t, [> `Msg of string]) result Lwt.t
  (** [connect_as_client ~switch underlying key digest] is an endpoint using flow [underlying].
      If [digest] requires TLS, it performs a TLS handshake. It uses [key] as its private key
      and checks that the server is the one required by [auth]. *)
end
